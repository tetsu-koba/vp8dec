#!/bin/bash -eux
file `which zig`
zig version
uname -m
echo $PATH

case "$OSTYPE" in
    darwin*) case "$HOSTTYPE" in
		 arm64) LIBDIR=/opt/homebrew/lib;INCLUDE=/opt/homebrew/include;;
		 *)	LIBDIR=/usr/local/lib;INCLUDE=/usr/local/include;;
	     esac ;;
     *) LIBDIR=/usr/lib;INCLUDE=/usr/include;;
esac

if [ $# -eq 0 ]; then
    OPTS=-Doptimize=Debug
else
    OPTS=-Doptimize=$1
fi
zig build
for i in src/*_test.zig; do
    zig test $OPTS $i -I$INCLUDE -L$LIBDIR -lvpx -lc
done
cmp testfiles/output.i420 testfiles/sample01.i420
cmp testfiles/output2.i420 testfiles/sample02.i420

