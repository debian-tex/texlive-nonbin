#!/bin/sh
#Test 2: install texlive/2012
echo "=== TeX Live Test System ==="
echo "=== Test 2: install/remove/install/purge texlive/2012 ==="
echo ""
echo "=== INSTALL APTITUDE"
apt-get install  --allow-unauthenticated --assume-yes  aptitude
aptargs="--without-recommends --assume-yes -o Aptitude::CmdLine::Ignore-Trust-Violations=yes"
echo "=== START INSTALL TEST VERSION"
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
aptitude install $aptargs texlive
echo "=== START REMOVE"
aptitude remove $aptargs texlive
echo "=== START INSTALL"
aptitude install $aptargs texlive
echo "=== START PURGE"
aptitude purge $aptargs '~ntexlive'
echo "=== END"
