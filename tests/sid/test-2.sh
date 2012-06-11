#!/bin/sh

aptargs="--assume-yes --allow-unauthenticated"

echo "=== TeX Live Test System ==="
echo "=== Test 2: install/remove/install/purge texlive/2012 ==="
echo ""

echo "=== START INSTALL TEST VERSION"
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
apt-get install $aptargs texlive

echo "=== START REMOVE"
apt-get remove $aptargs texlive

echo "=== START INSTALL"
apt-get install $aptargs texlive

echo "=== START PURGE"
aptitude purge --assume-yes '~ntexlive'

echo "=== END"
