#!/bin/bash
#

#texlive-fonts-extra;usr/share/texlive/texmf-dist/fonts/opentype/public/libertineotf/LinLibertine_aZL.otf;fonts-linuxlibertine

# feed *.lintian.log into that

for i in $(grep duplicate-font-file |	\
	sed 	-e 's/^W: //'				\
		-e 's/: duplicate-font-file also in /;/' \
		-e 's/\ /;/' -e 's/\x28//' -e 's/\x29//' \
		-e 's/\[//' -e 's/\]//') ; do
  # Name of TL package
  pkg=$(echo $i | awk -F";" '{print$1}')
  # Font name + patch in TL
  tlpath=$(echo $i | awk -F";" '{print$3}')
  # Debian package containing the duplicate
  debpkg=$(echo $i | awk -F";" '{print$2}')
  fntname=$(basename $tlpath)
  debpath=$(grep /$fntname /var/lib/dpkg/info/$debpkg.list | sed -e 's!^/!!')
  echo "$debpath $tlpath" >> $pkg.links.dist
  echo "depends;$pkg;$debpkg" >> tpmadds
  shortn=$(echo $tlpath | sed -e 's!^usr/share/texlive/!!')
  echo "blacklist;file;$shortn" >> tpmadds
done
