#!/bin/bash

olddir=`mktemp -dt old.XXXXXX` || exit 1
newdir=`mktemp -dt new.XXXXXX` || exit 1

dpkg-deb -e $1 $olddir
dpkg-deb -e $2 $newdir

rm $olddir/md5sums
rm $newdir/md5sums

dpkg-deb -c $1 | awk '{print$1" "$6" "$7" "$8}' > $olddir/filelist
dpkg-deb -c $2 | awk '{print$1" "$6" "$7" "$8}' > $newdir/filelist

diff -urN $olddir $newdir

rm -rf $olddir
rm -rf $newdir
