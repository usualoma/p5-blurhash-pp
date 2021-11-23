package BlurHash::PP;

# Blurhash
# https://blurha.sh/
#
# This version has been translated from the python version of blurhash.
# https://github.com/halcy/blurhash-python

our $VERSION = '0.0.1';

use strict;
use warnings;

use Exporter qw(import);
use List::Util qw(min max);
use Math::Trig qw(pi);
use POSIX qw(floor);

our @EXPORT_OK = qw(decode_blurhash encode_blurhash);

## Alphabet for base 83
my $alphabet
    = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~';
my %alphabet_values = do {
    my $i = 0;
    map { $_ => $i++ } split //, $alphabet;
};

sub base83_decode {
    my ($str) = @_;

    my $value = 0;
    for my $c ( split //, $str ) {
        $value = $value * 83 + $alphabet_values{$c};
    }
    return $value;
}

sub base83_encode {
    my ( $value, $length ) = @_;

    my $result = "";
    for my $i ( 1 .. $length ) {
        my $digit = $value / ( 83**( $length - $i ) ) % 83;
        $result .= substr( $alphabet, $digit, 1 );
    }
    return $result;
}

sub srgb_to_linear {
    my ($value) = @_;

    $value /= 255.0;
    if ( $value <= 0.04045 ) {
        return $value / 12.92;
    }
    return ( ( $value + 0.055 ) / 1.055 )**2.4;
}

sub sign_pow {
    my ( $value, $exp ) = @_;
    return ( abs($value)**$exp ) * ( $value < 0 ? -1 : 1 );
}

sub linear_to_srgb {
    my ($value) = @_;
    $value = max( 0.0, min( 1.0, $value ) );

    if ( $value <= 0.0031308 ) {
        return int( $value * 12.92 * 255 + 0.5 );
    }

    return int( ( 1.055 * ( $value**( 1 / 2.4 ) ) - 0.055 ) * 255 + 0.5 );
}

sub blurhash_components {
    my ($blurhash) = @_;

    if ( length($blurhash) < 6 ) {
        die "BlurHash must be at least 6 characters long.";
    }

    my $size_info = base83_decode( $blurhash->[0] );
    my $size_y    = int( $size_info / 9 ) + 1;
    my $size_x    = ( $size_info % 9 ) + 1;

    return ( $size_x, $size_y );
}

sub decode_blurhash {
    my ( $blurhash, $width, $height, $punch, $linear ) = @_;
    $punch ||= 1.0;

    if ( length($blurhash) < 6 ) {
        die "BlurHash must be at least 6 characters long.";
    }

    # Decode metadata
    my $size_info = base83_decode( substr( $blurhash, 0, 1 ) );
    my $size_y    = int( $size_info / 9 ) + 1;
    my $size_x    = int( $size_info % 9 ) + 1;

    my $quant_max_value = base83_decode( substr( $blurhash, 1, 1 ) );
    my $real_max_value  = ( ( $quant_max_value + 1 ) / 166.0 ) * $punch;

    # Make sure we at least have the right number of characters
    if ( length($blurhash) != 4 + 2 * $size_x * $size_y ) {
        die "Invalid BlurHash length.";
    }

    # Decode DC component
    my $dc_value = base83_decode( substr( $blurhash, 2, 4 ) );
    my @colours  = (
        [   srgb_to_linear( $dc_value >> 16 ),
            srgb_to_linear( ( $dc_value >> 8 ) & 255 ),
            srgb_to_linear( $dc_value & 255 )
        ]
    );

    # Decode AC components
    for ( my $component = 1; $component < $size_x * $size_y; $component++ ) {
        my $ac_value = base83_decode( substr( $blurhash, 4 + $component * 2, 2 ) );
        push @colours,
            [
            sign_pow( ( ( int( $ac_value / ( 19 * 19 ) ) ) - 9.0 ) / 9.0, 2.0 ) * $real_max_value,
            sign_pow( ( ( int( $ac_value / 19 ) % 19 ) - 9.0 ) / 9.0,     2.0 ) * $real_max_value,
            sign_pow( ( ( $ac_value % 19 ) - 9.0 ) / 9.0,                 2.0 ) * $real_max_value
            ];
    }

    # Return image RGB values, as a list of lists of lists,
    # consumable by something like numpy or PIL.
    my @pixels;
    for ( my $y = 0; $y < $height; $y++ ) {
        my @pixel_row;
        for ( my $x = 0; $x < $width; $x++ ) {
            my @pixel = ( 0.0, 0.0, 0.0 );

            for ( my $j = 0; $j < $size_y; $j++ ) {
                for ( my $i = 0; $i < $size_x; $i++ ) {
                    my $basis  = cos( pi * $x * $i / $width ) * cos( pi * $y * $j / $height );
                    my $colour = $colours[ $i + $j * $size_x ];
                    $pixel[0] += $colour->[0] * $basis;
                    $pixel[1] += $colour->[1] * $basis;
                    $pixel[2] += $colour->[2] * $basis;
                }
            }

            unless ($linear) {
                push @pixel_row,
                    [
                    linear_to_srgb( $pixel[0] ),
                    linear_to_srgb( $pixel[1] ),
                    linear_to_srgb( $pixel[2] ),
                    ];
            }
            else {
                push @pixel_row, \@pixel;
            }
        }
        push @pixels, \@pixel_row;
    }
    return \@pixels;
}

sub encode_blurhash {
    my ( $image, $components_x, $components_y, $linear ) = @_;
    $components_x ||= 4;
    $components_y ||= 4;

    if ( $components_x < 1 || $components_x > 9 || $components_y < 1 || $components_y > 9 ) {
        die "x and y component counts must be between 1 and 9 inclusive.";
    }

    my $height = @$image;
    my $width  = @{ $image->[0] };

    my @image_linear = ();

    unless ($linear) {
        for ( my $i = 0; $i < $height; $i++ ) {
            my @image_linear_line = ();
            for ( my $j = 0; $j < $width; $j++ ) {
                push @image_linear_line,
                    [
                    srgb_to_linear( $image->[$i][$j][0] ),
                    srgb_to_linear( $image->[$i][$j][1] ),
                    srgb_to_linear( $image->[$i][$j][2] )
                    ];
            }
            push @image_linear, \@image_linear_line;
        }
    }
    else {
        @image_linear = @$image;
    }

    my @components;
    my $max_ac_component = 0.0;
    for ( my $j = 0; $j < $components_y; $j++ ) {
        for ( my $i = 0; $i < $components_x; $i++ ) {
            my $norm_factor = ( $i == 0 && $j == 0 ) ? 1.0 : 2.0;
            my @component   = ( 0.0, 0.0, 0.0 );

            for ( my $y = 0; $y < $height; $y++ ) {
                for ( my $x = 0; $x < $width; $x++ ) {
                    my $basis = $norm_factor * cos( pi * $i * $x / $width ) *
                        cos( pi * $j * $y / $height );
                    $component[0] += $basis * $image_linear[$y][$x][0];
                    $component[1] += $basis * $image_linear[$y][$x][1];
                    $component[2] += $basis * $image_linear[$y][$x][2];
                }
            }

            $component[0] /= ( $width * $height );
            $component[1] /= ( $width * $height );
            $component[2] /= ( $width * $height );
            push @components, \@component;

            if ( !( $i == 0 && $j == 0 ) ) {
                $max_ac_component = max(
                    $max_ac_component,
                    abs( $component[0] ),
                    abs( $component[1] ),
                    abs( $component[2] )
                );
            }
        }
    }

    # Encode components
    my $dc_value
        = ( linear_to_srgb( $components[0][0] ) << 16 )
        + ( linear_to_srgb( $components[0][1] ) << 8 )
        + linear_to_srgb( $components[0][2] );

    my $quant_max_ac_component = int( max( 0, min( 82, floor( $max_ac_component * 166 - 0.5 ) ) ) );
    my $ac_component_norm_factor = ( $quant_max_ac_component + 1 ) / 166.0;

    my @ac_values;
    for my $c ( @components[ 1 .. $#components ] ) {
        my ( $r, $g, $b ) = @$c;
        push @ac_values,
            int(
            max(0.0,
                min( 18.0, floor( sign_pow( $r / $ac_component_norm_factor, 0.5 ) * 9.0 + 9.5 ) )
            )
            ) * 19 * 19 + int(
            max(0.0,
                min( 18.0, floor( sign_pow( $g / $ac_component_norm_factor, 0.5 ) * 9.0 + 9.5 ) )
            )
            ) * 19 + int(
            max(0.0,
                min( 18.0, floor( sign_pow( $b / $ac_component_norm_factor, 0.5 ) * 9.0 + 9.5 ) )
            )
            );
    }

    my $blurhash = "";
    $blurhash .= base83_encode( ( $components_x - 1 ) + ( $components_y - 1 ) * 9, 1 );

    $blurhash .= base83_encode( $quant_max_ac_component, 1 );
    $blurhash .= base83_encode( $dc_value, 4 );
    for my $ac_value (@ac_values) {
        $blurhash .= base83_encode( $ac_value, 2 );
    }

    return $blurhash;
}

1;
