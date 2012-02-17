#!/bin/bash
# $Id$
#
# TeX Live 2008 ships many "binaries" as symlinks to ../../texmf-*/...
# which we have to fix here
#
# Norbert Preining, 2008
# GPL

set -e

for i in `find debian/ -wholename 'debian/texlive-*/usr/bin/*' -type l` ; do
	ln=`readlink $i`
	case "$ln" in 
	../../texmf*)
	  nn=`echo $ln | sed -e 's;^\.\./\.\./texmf[^/]*/;../share/texmf-texlive/;'`
	  ln -sf $nn $i
	  ;;
	esac
done


