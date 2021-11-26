use strict;
use warnings;
use Test::More 0.98;
use FindBin;

BEGIN {
    plan skip_all => "Image::Magick is not installed."
        unless eval { require Imager; };
}

use Image::Magick;
use BlurHash::PP qw(encode_blurhash);

my %test_data = (
    "$FindBin::Bin/dataset/01.jpg" => 'UXJ@zSRQx]sm^,Wnx]kD?^ShRoX7tnRjWAkW',
    "$FindBin::Bin/dataset/02.jpg" => 'UUDm:xNf0i$|9Gs,%LNItTWXWAWCNgW?oIs.',
);

sub encode {
    my ($file) = @_;

    my $img = Image::Magick->new;
    $img->Read($file);

    my ( $w, $h ) = $img->Get( 'Width', 'Height' );
    my @pixels = $img->GetPixels( map => 'RGB', height => $h, width => $w );
    my $img_data;
    for ( my $i = 0; $i < $h; $i++ ) {
        my @line;
        for ( my $j = 0; $j < $w; $j++ ) {
            push @line, [ map { $_ / 256 } splice( @pixels, 0, 3 ) ];
        }
        push @$img_data, \@line;
    }

    return encode_blurhash($img_data);
}

while ( my ( $file, $hash ) = each %test_data ) {
    subtest $file => sub {
        is encode($file), $hash;
    };
}

done_testing;
