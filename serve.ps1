# Ingilizce Shorts local server (no Node/Python needed).
#
#   powershell -ExecutionPolicy Bypass -File serve.ps1            # LAN mode (phone access)
#   powershell -ExecutionPolicy Bypass -File serve.ps1 -LocalOnly # localhost only
#   powershell -ExecutionPolicy Bypass -File serve.ps1 -Port 8200
#
# LAN mode listens on ALL interfaces so a phone on the same Wi-Fi can open
# the app via this computer's IP. Windows requires a one-time (admin) URL
# reservation + firewall rule for that -- if they are missing, this script
# prints the exact commands and falls back to localhost instead of dying.

param(
  [int]$Port = 8161,
  [switch]$LocalOnly
)

$root = $PSScriptRoot
$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'
  '.mjs'  = 'text/javascript; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.webmanifest' = 'application/manifest+json; charset=utf-8'
  '.svg'  = 'image/svg+xml'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.ico'  = 'image/x-icon'
  '.woff2'= 'font/woff2'
}

function Get-LanIPs {
  Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Select-Object -ExpandProperty IPAddress
}

$listener = New-Object System.Net.HttpListener
$boundLan = $false

if (-not $LocalOnly) {
  # Try binding all interfaces first.
  try {
    $listener.Prefixes.Add("http://+:$Port/")
    $listener.Start()
    $boundLan = $true
  } catch [System.Net.HttpListenerException] {
    $code = $_.Exception.NativeErrorCode
    $listener.Close()
    $listener = New-Object System.Net.HttpListener
    if ($code -eq 5) {   # ERROR_ACCESS_DENIED -> missing URL reservation
      Write-Host ""
      Write-Host "PHONE ACCESS NOT ENABLED YET." -ForegroundColor Yellow
      Write-Host "Windows needs a one-time setup to allow serving on the network." -ForegroundColor Yellow
      Write-Host "Run these two commands ONCE in an *Administrator* PowerShell:" -ForegroundColor Yellow
      Write-Host ""
      Write-Host "  netsh http add urlacl url=http://+:$Port/ user=Everyone" -ForegroundColor Cyan
      Write-Host "  netsh advfirewall firewall add rule name=`"Ingilizce Shorts $Port`" dir=in action=allow protocol=TCP localport=$Port" -ForegroundColor Cyan
      Write-Host ""
      Write-Host "Then restart this script. Falling back to LOCALHOST ONLY for now." -ForegroundColor Yellow
      Write-Host ""
    } elseif ($code -eq 183 -or $code -eq 32) {  # already in use
      Write-Host "ERROR: port $Port is already in use (is another copy of the server running?)." -ForegroundColor Red
      Write-Host "Stop it or choose another port:  serve.ps1 -Port 8162" -ForegroundColor Red
      exit 1
    } else {
      Write-Host "ERROR starting network listener: $($_.Exception.Message)" -ForegroundColor Red
    }
  }
}

if (-not $boundLan) {
  try {
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
  } catch [System.Net.HttpListenerException] {
    Write-Host "ERROR: could not bind http://localhost:$Port/ - $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "The port may be in use. Try:  serve.ps1 -Port 8162" -ForegroundColor Red
    exit 1
  }
}

Write-Host ""
Write-Host "  Ingilizce Shorts is running" -ForegroundColor Green
Write-Host "  ----------------------"
Write-Host "  On this computer:  http://localhost:$Port"
if ($boundLan) {
  $ips = @(Get-LanIPs)
  if ($ips.Count -gt 0) {
    foreach ($ip in $ips) {
      Write-Host "  On your phone:     http://${ip}:$Port   (same Wi-Fi network)" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  If the phone cannot connect, allow the port through the firewall (admin):" -ForegroundColor DarkGray
    Write-Host "  netsh advfirewall firewall add rule name=`"Ingilizce Shorts $Port`" dir=in action=allow protocol=TCP localport=$Port" -ForegroundColor DarkGray
  } else {
    Write-Host "  (No LAN IPv4 address found - are you connected to Wi-Fi/Ethernet?)" -ForegroundColor Yellow
  }
} else {
  Write-Host "  (localhost only - phone access disabled this run)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Ctrl+C to stop."
Write-Host ""

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
      $path = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)
      if ($path -eq '/') { $path = '/index.html' }
      $full = [System.IO.Path]::GetFullPath((Join-Path $root ($path.TrimStart('/') -replace '/', '\')))
      if ((Test-Path $full -PathType Container) -and (Test-Path (Join-Path $full 'index.html'))) {
        $full = Join-Path $full 'index.html'
      }
      if ($full.StartsWith($root) -and (Test-Path $full -PathType Leaf)) {
        $ext = [System.IO.Path]::GetExtension($full).ToLower()
        $type = $mime[$ext]
        if (-not $type) { $type = 'application/octet-stream' }
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $res.ContentType = $type
        $res.ContentLength64 = $bytes.Length
        $res.Headers.Add('Cache-Control', 'no-cache')
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
      } else {
        $res.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
        $res.OutputStream.Write($msg, 0, $msg.Length)
      }
    } catch {
      try { $res.StatusCode = 500 } catch {}
    } finally {
      try { $res.OutputStream.Close() } catch {}
    }
  }
} finally {
  $listener.Stop()
}
