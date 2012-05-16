#!/bin/sh

aptargs="--assume-yes --allow-unauthenticated"

echo "=== TeX Live Test System ==="
echo "=== Test 1: install/remove/install/purge texlive-full/2012 ==="

echo ""
echo "=== START INSTALL TEST VERSION"
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
apt-get install $aptargs texlive-full

echo "=== START REMOVE"
apt-get remove $aptargs texlive-full

echo "=== START INSTALL"
apt-get install $aptargs texlive-full

echo "=== START PURGE"
aptitude purge '~ntexlive'

echo "=== END"
