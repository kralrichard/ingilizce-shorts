#!/usr/bin/perl
# Ingilizce Shorts - veri uretici
#   kullanim: perl build.pl kelimeler.js cmudict.dict pairs.txt ../veri
#   girdi : kelimeler.js  (seri-ingilizce bankasi: kelime|tur|Turkce|IPA|okunus)
#           cmudict.dict  (ARPAbet telaffuz)
#           pairs.txt     ("Turkce | English", Tatoeba eng-tur)
#   cikti : ../veri/v00.js .. v09.js  (her parca 2000 kelime + 400 cumle)
#           ../veri/meta.js
use strict;
use warnings;
use utf8;
binmode(STDERR, ':encoding(UTF-8)');

my ($fWords, $fCmu, $fPairs, $outDir) = @ARGV;
die "kullanim: perl build.pl kelimeler.js cmudict.dict pairs.txt cikti_dizini\n"
    unless defined $outDir;

my $NW    = 20000;   # kelime karti
my $PER   = 5;       # kac kelimeden sonra bir cumle
my $NS    = $NW / $PER;   # 4000 cumle karti
my $SHARD = 2000;    # parca basina kelime

# ---------------------------------------------------------------- 1. CMUdict
my %cmu;
open(my $cd, '<:encoding(UTF-8)', $fCmu) or die "cmudict: $!";
while (my $l = <$cd>) {
    chomp $l; $l =~ s/[\r\n]//g;
    $l =~ s/\s+#.*$//;
    next unless $l =~ /^(\S+)\s+(.+)$/;
    my ($w, $ph) = (lc $1, $2);
    next if $w =~ /\(\d\)$/;
    $cmu{$w} = $ph unless exists $cmu{$w};
}
close $cd;
warn "cmudict: " . scalar(keys %cmu) . "\n";

my %IPA = (
  AA=>'ɑ', AE=>'æ', AH=>'ʌ', AO=>'ɔ', AW=>'aʊ', AY=>'aɪ', B=>'b', CH=>'tʃ',
  D=>'d', DH=>'ð', EH=>'ɛ', ER=>'ɜr', EY=>'eɪ', F=>'f', G=>'ɡ', HH=>'h',
  IH=>'ɪ', IY=>'i', JH=>'dʒ', K=>'k', L=>'l', M=>'m', N=>'n', NG=>'ŋ',
  OW=>'oʊ', OY=>'ɔɪ', P=>'p', R=>'r', S=>'s', SH=>'ʃ', T=>'t', TH=>'θ',
  UH=>'ʊ', UW=>'u', V=>'v', W=>'w', Y=>'j', Z=>'z', ZH=>'ʒ',
);
my %TR = (
  AA=>'a', AE=>'e', AH=>'a', AO=>'o', AW=>'au', AY=>'ay', B=>'b', CH=>'ç',
  D=>'d', DH=>'d', EH=>'e', ER=>'ır', EY=>'ey', F=>'f', G=>'g', HH=>'h',
  IH=>'i', IY=>'i', JH=>'c', K=>'k', L=>'l', M=>'m', N=>'n', NG=>'ng',
  OW=>'ou', OY=>'oy', P=>'p', R=>'r', S=>'s', SH=>'ş', T=>'t', TH=>'t',
  UH=>'u', UW=>'u', V=>'v', W=>'v', Y=>'y', Z=>'z', ZH=>'j',
);
my %VOWEL = map { $_ => 1 } qw(AA AE AH AO AW AY EH ER EY IH IY OW OY UH UW);

# ARPAbet -> (IPA, Turkce okunus).  $stresli=1 ise cok heceli kelimede
# birincil vurgulu unlu BUYUK harf olur (kelime karti icin).
sub arpa2 {
    my ($ph, $stresli) = @_;
    my @p = split /\s+/, $ph;
    my $syl = grep { my $s = $_; $s =~ s/[012]$//; $VOWEL{$s} } @p;
    my ($ipa, $tr, $marked) = ('', '', 0);
    for my $s (@p) {
        my $stress = ($s =~ s/([012])$//) ? $1 : '';
        next unless exists $IPA{$s};
        my ($ip, $tp) = ($IPA{$s}, $TR{$s});
        if ($s eq 'AH' && $stress eq '0') { $ip = 'ə'; $tp = 'ı'; }
        if ($stresli && $stress eq '1' && $VOWEL{$s} && $syl > 1 && !$marked) {
            $tp = uc $tp; $marked = 1;
        }
        $ipa .= $ip; $tr .= $tp;
    }
    return ($ipa, $tr);
}

# tek kelimenin cumle icindeki okunusu (vurgu buyutmesi yok) - onbellekli
# kisaltmalar: CMUdict "dr." icin "drive" veriyor, elle duzeltiyoruz
my %ELLE = (
  mr => 'mistır', mrs => 'misız', ms => 'miz', dr => 'daktır', st => 'seynt',
  mt => 'maunt', jr => 'cuniır', sr => 'siniır', tv => 'tivi', dvd => 'dividi',
  ok => 'okey',
);
my %okuBellek;
sub oku1 {
    my ($w) = @_;
    return $ELLE{$w} if exists $ELLE{$w};
    return $okuBellek{$w} if exists $okuBellek{$w};
    my $r = '';
    if (exists $cmu{$w}) { (undef, $r) = arpa2($cmu{$w}, 0); }
    return $okuBellek{$w} = $r;
}

# cumlenin Turkce okunusu; ikinci deger: okunusu bulunamayan kelime sayisi
sub okuCumle {
    my ($e) = @_;
    my (@out, $miss);
    $miss = 0;
    for my $tok (split /\s+/, $e) {
        my ($pre, $core, $post) = ('', $tok, '');
        $pre  = $1 if $core =~ s/^([^A-Za-z']+)//;
        $post = $1 if $core =~ s/([^A-Za-z']+)$//;
        next unless length $core;
        my $r = oku1(lc $core);
        if (!length $r) { $miss++; $r = lc $core; }
        push @out, $pre . $r . $post;
    }
    return (join(' ', @out), $miss);
}

# ---------------------------------------------------------- 2. kelime bankasi
my (@W, %rank);
open(my $wf, '<:encoding(UTF-8)', $fWords) or die "kelimeler: $!";
while (my $l = <$wf>) {
    chomp $l; $l =~ s/[\r\n]//g;
    # dikkat: /^window/ demek "window" kelimesini de eler
    next if $l =~ m{^\s*[*/]} || $l =~ /^window\.\w+\s*=/ || $l =~ /^`/;
    next unless $l =~ /\|/;
    my @f = split /\|/, $l, 5;
    next unless @f >= 3;
    $f[3] = '' unless defined $f[3];
    $f[4] = '' unless defined $f[4];
    push @W, \@f;
    $rank{ lc $f[0] } = $#W unless exists $rank{ lc $f[0] };
    last if @W >= $NW;
}
close $wf;
warn "kelime: " . scalar(@W) . "\n";
die "kelime bankasi eksik\n" if @W < $NW;

# "goes" listede varsa "go" govdesi aranmaz - sahte eslesmeyi onler
sub bases {
    my ($t) = @_;
    my @b = ($t);
    if    ($t =~ /^(.+)ies$/)             { push @b, "$1y"; }
    elsif ($t =~ /^(.+[sxz]|.+[cs]h)es$/) { push @b, $1; }
    elsif ($t =~ /^(.+[^s])s$/)           { push @b, $1; }
    if    ($t =~ /^(.+)ied$/)             { push @b, "$1y"; }
    elsif ($t =~ /^(.+)ed$/)              { push @b, $1, "$1e"; }
    if    ($t =~ /^(.+)ing$/)             { push @b, $1, "$1e"; }
    if    ($t =~ /^(.+)([bdglmnprt])\2(ed|ing)$/) { push @b, "$1$2"; }
    if    ($t =~ /^(.+)'(s|re|ve|ll|d|m)$/)       { push @b, $1; }
    return @b;
}

# ------------------------------------------------------------- 3. cumleleri tara
my (@en, @tr, @sc, @tokset);   # secilen adaylar
my (%best, %dup);              # kelime -> [skor, id]
my @havuz;                     # kolay cumle havuzu: [skor, id]
my $tarandi = 0;

open(my $sf, '<:encoding(UTF-8)', $fPairs) or die "pairs: $!";
while (my $l = <$sf>) {
    chomp $l; $l =~ s/[\r\n]//g;
    next unless $l =~ /^(.+?)\s\|\s(.+)$/;
    my ($t, $e) = ($1, $2);
    $tarandi++;
    next if length($e) > 110;
    my $key = lc $e; $key =~ s/[^a-z ]//g;
    next if $dup{$key}++;

    my $s = lc $e;
    $s =~ s/[^a-z' ]/ /g;
    my @tok = grep { length } split /\s+/, $s;
    my $n = scalar @tok;
    next if $n < 2 || $n > 16;
    # cumle karti havuzu icin dar elek; ornek cumlede kapsam onemli
    my $temiz = ($n >= 3 && $n <= 9 && length($e) <= 80
                 && $e !~ /[0-9]/ && $e !~ /["\x{201c}\x{201d}]/);

    # zorluk = en nadir kelimenin sirasi
    my $hard = 0;
    my @bl;
    for my $tk (@tok) {
        my @b = exists $rank{$tk} ? ($tk) : bases($tk);
        my $rk = 26000;
        for my $bw (@b) { $rk = $rank{$bw} if exists $rank{$bw} && $rank{$bw} < $rk }
        $hard = $rk if $rk > $hard;
        push @bl, \@b;
    }
    my $score = abs($n - 6) + $hard / 3000;
    $score += 1.5 if $s =~ /\btom\b/;
    $score += 0.8 if $s =~ /\b(mary|john|jane|bob|ken|yumi|jim)\b/;

    my ($okunus, $miss) = okuCumle($e);
    $score += 4 * $miss;                    # okunusu eksik cumle geride kalsin

    # bu cumle hangi kelimeler icin en iyi adayi gecer?
    my @kazanan;
    my %seen;
    for my $bl (@bl) {
        for my $bw (@$bl) {
            next unless exists $rank{$bw};
            next if $seen{$bw}++;
            push @kazanan, $bw
                if !exists $best{$bw} || $score < $best{$bw}[0];
        }
    }
    my $havuzluk = ($temiz && $miss == 0 && $hard < 6000 && $score < 4);

    next unless @kazanan || $havuzluk;

    push @en, $e; push @tr, $t; push @sc, $score;
    push @tokset, [ grep { exists $rank{$_} } keys %seen ];
    my $id = $#en;
    $best{$_} = [ $score, $id ] for @kazanan;
    push @havuz, [ $score, $id ] if $havuzluk;
}
close $sf;
warn "taranan: $tarandi  aday: " . scalar(@en) . "  havuz: " . scalar(@havuz) . "\n";
warn "ornegi olan kelime: " . scalar(keys %best) . "\n";

# ornegi bulunamayan kelime icin cekim govdesinin ornegini odunc al
# ("nailing" -> "nail" cumlesi). Sadece duzenli cekimlerde.
my $odunc = 0;
for my $i (0 .. $#W) {
    my $w = lc $W[$i][0];
    next if exists $best{$w};
    for my $b (bases($w)) {
        next if $b eq $w;
        next unless exists $best{$b};
        $best{$w} = $best{$b};
        $odunc++;
        last;
    }
}
warn "govdeden odunc ornek: $odunc\n";

# ----------------------------------------------- 4. cumle kartlarini yerlestir
# Havuz kolaydan zora sirali. Her yuvada once o bloktaki 5 kelimeden birini
# iceren cumle denenir (kart akisi tutarli olsun), yoksa siradaki en kolay.
# kelime kartinda ornek olarak gecen cumle, cumle kartinda tekrar cikmasin
my %ornekId;
$ornekId{ $_->[1] } = 1 for values %best;
my @temizHavuz = grep { !$ornekId{ $_->[1] } } @havuz;
warn "havuz: " . scalar(@havuz) . " -> ornek disi: " . scalar(@temizHavuz) . "\n";
@havuz = @temizHavuz if @temizHavuz >= $NS * 1.2;

@havuz = sort { $a->[0] <=> $b->[0] } @havuz;
my %havuzSira;                      # id -> havuzdaki sira
$havuzSira{ $havuz[$_][1] } = $_ for 0 .. $#havuz;

my %kelimeHavuz;                    # kelime -> [havuz sirasi, ...]
for my $i (0 .. $#havuz) {
    my $id = $havuz[$i][1];
    push @{ $kelimeHavuz{$_} }, $i for @{ $tokset[$id] };
}

my (@kart, %alindi);
my $imlec = 0;
for my $slot (0 .. $NS - 1) {
    my $sec;
    # bu slottan onceki 5 kelime
    for my $k ($slot * $PER .. $slot * $PER + $PER - 1) {
        my $w = lc $W[$k][0];
        next unless $kelimeHavuz{$w};
        for my $i (@{ $kelimeHavuz{$w} }) {
            next if $alindi{$i};
            $sec = $i if !defined $sec || $i < $sec;
            last;
        }
    }
    if (!defined $sec) {
        $imlec++ while $imlec <= $#havuz && $alindi{$imlec};
        $sec = $imlec;
    }
    last if $sec > $#havuz;
    $alindi{$sec} = 1;
    push @kart, $havuz[$sec][1];
}
warn "cumle karti: " . scalar(@kart) . "\n";
die "havuz yetersiz (" . scalar(@kart) . "/$NS)\n" if @kart < $NS;

# ------------------------------------------------------------- 5. parcalari yaz
my ($ornekVar, $ornekYok) = (0, 0);
mkdir $outDir unless -d $outDir;
my $parca = 0;
for (my $off = 0; $off < $NW; $off += $SHARD) {
    my @wl;
    for my $i ($off .. $off + $SHARD - 1) {
        my ($w, $pos, $anlam, $ipa, $okunus) = @{ $W[$i] };
        my ($eEn, $eTr, $eOku) = ('', '', '');
        my $b = $best{ lc $w };
        if ($b) {
            my $id = $b->[1];
            $eEn = $en[$id]; $eTr = $tr[$id];
            ($eOku) = okuCumle($eEn);
            $ornekVar++;
        } else { $ornekYok++ }
        s/\|/,/g, s/`/'/g for ($anlam, $eEn, $eTr, $eOku);
        push @wl, join('|', $w, $pos, $anlam, $ipa, $okunus, $eEn, $eTr, $eOku);
    }
    my @sl;
    my $sOff = $off / $PER;
    for my $j ($sOff .. $sOff + $SHARD / $PER - 1) {
        my $id = $kart[$j];
        my ($e, $t) = ($en[$id], $tr[$id]);
        my ($o) = okuCumle($e);
        s/\|/,/g, s/`/'/g for ($e, $t, $o);
        push @sl, join('|', $e, $t, $o);
    }
    my $ad = sprintf("%s/v%02d.js", $outDir, $parca);
    open(my $o, '>:encoding(UTF-8)', $ad) or die "yaz: $!";
    print $o "PARCA($parca,`\n" . join("\n", @wl) . "\n`,`\n" . join("\n", @sl) . "\n`);\n";
    close $o;
    warn sprintf("v%02d.js: %d kelime + %d cumle\n", $parca, scalar(@wl), scalar(@sl));
    $parca++;
}

open(my $m, '>:encoding(UTF-8)', "$outDir/meta.js") or die "meta: $!";
print $m "window.META={kelime:$NW,cumle:$NS,parca:$parca,bloktaKelime:$PER,parcaKelime:$SHARD};\n";
close $m;

warn "ornek cumlesi olan kelime: $ornekVar  olmayan: $ornekYok\n";
warn "bitti\n";
