#!/bin/sh
#Etch Test 1: install etch/tetex+extra -> dist-upgrade sid (texlive 2007)
echo "=== TeX Live Test System ==="
echo "=== Etch Test 7: install etch/tetex+extra -> dist-upgrade sid (tl2009) ==="
echo ""
echo "=== START INSTALL TETEX ETCH VERSION"
apt-get install --allow-unauthenticated --assume-yes tetex-bin tetex-extra
echo "=== START INSTALL DIST-UPGRADE SID"
echo "deb http://ftp.de.debian.org/debian sid main" > /etc/apt/sources.list
echo "deb file:/ pool/" >> /etc/apt/sources.list
apt-get update --allow-unauthenticated --assume-yes 
apt-get dist-upgrade --allow-unauthenticated --assume-yes
echo "=== END"
