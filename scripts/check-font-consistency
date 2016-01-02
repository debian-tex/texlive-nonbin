#!/bin/bash
#
# check-font-consistency
# Norbert Preining, public domain
# TeX Live packaging for Debian
# check that the link definitions in .links.dists are not out-of-date
# by checking against files installed on the system and in the TL git/svn
#
for i in `find . -name \*.links.dist` ; do
  echo "checking $i:"
  cat $i | while read a b ; do
    # a is in system, b is in texlive git
    case $a in
      usr/share/fonts/*) 
        if ! [ -r "/$a" ] ; then
          echo "missing $a"
        fi
        ;;
    esac
    case $b in 
      usr/share/texlive/texmf-dist/fonts/opentype/*|usr/share/texlive/texmf-dist/fonts/truetype/*)
        c=`echo $b | sed -e 's!^usr/share/texlive/!!'`
        if ! [ -r "/src/TeX/texlive.git/Master/$c" ] ; then
          echo "missing $b (as $c)"
        fi
        ;;
    esac
  done
done

# now check also the blacklist entries
cat all/debian/cfg.d/font-ignore.cfg | while read a ; do
  case $a in
    blacklist\;file\;texmf-dist/fonts/opentype/*|blacklist\;file\;texmf-dist/fonts/truetype/*)
      c=`echo $a | sed -e 's!blacklist;file;!!'`
      if ! [ -r "/src/TeX/texlive.git/Master/$c" ] ; then
        echo "blacklist error: $a"
      fi
      ;;
  esac
done
