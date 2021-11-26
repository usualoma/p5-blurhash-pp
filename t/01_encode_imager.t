use strict;
use warnings;
use Test::More 0.98;
use FindBin;

BEGIN {
    plan skip_all => "Imager is not installed."
        unless eval { require Imager; };
}

use Imager;
use BlurHash::PP qw(encode_blurhash);

my %test_data = (
    "$FindBin::Bin/dataset/01.jpg" => 'UXJ@wMRQx]sm^,Wnx]f,?^ShNLX7tnRjWAkW',
    "$FindBin::Bin/dataset/02.jpg" => 'UUDwRJNf0i$|9Gs,%LNItTWXWAWCNgW?oIs.',
);

sub encode {
    my ($file) = @_;

    my $img = Imager->new;
    $img->read(file => $file)
      or die $img->errstr;

    my $img_data = [map {
        my $y = $_;
        my @colors = $img->getscanline(y=>$y);
        [ map { [($_->rgba)[0..2]] } @colors ];
    } (0..$img->getheight-1)];

    return encode_blurhash($img_data);
}

while (my ($file, $hash) = each %test_data) {
    subtest $file => sub {
        is encode($file), $hash;
    };
}

done_testing;
