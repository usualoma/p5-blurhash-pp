# NAME

BlurHash::PP - The encoder / decoder for BlurHash.

# SYNOPSIS

    use Imager;
    use BlurHash::PP qw(encode_blurhash decode_blurhash);

    my $img = Imager->new;
    $img->read(file => $file)
      or die $img->errstr;

    my $img_data = [map {
        my $y = $_;
        my @colors = $img->getscanline(y=>$y);
        [ map { [($_->rgba)[0..2]] } @colors ];
    } (0..$img->getheight-1)];

    print encode_blurhash($img_data);

# DESCRIPTION

BlurHash is a compact representation of a placeholder for an image.

https://blurha.sh/

# ORIGINAL VERSION

This perl version has been translated from the python version of blurhash.

https://github.com/halcy/blurhash-python

# LICENSE

Copyright (c) 2021 Taku AMANO

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# AUTHOR

Taku Amano <taku@taaas.jp>
