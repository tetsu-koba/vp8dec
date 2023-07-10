#!/bin/sh -eux
LIBDIR=/opt/homebrew/lib
INCLUDE=/opt/homebrew/include

if [ $# -eq 0 ]; then
    OPTS=-Doptimize=Debug
else
    OPTS=-Doptimize=$1
fi
zig build
for i in src/*_test.zig; do
    zig test $OPTS $i -I$INCLUDE -L$LIBDIR -lvpx -lc
    cmp testfiles/output.i420 testfiles/sample01.i420
done

