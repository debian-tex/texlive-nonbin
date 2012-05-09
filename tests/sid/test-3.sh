#!/bin/sh

aptargs="--assume-yes --allow-unauthenticated"

echo "=== TeX Live Test System ==="
echo "=== Test 3: dist-upgrade texlive-full from sid to test ==="
echo ""

echo "=== START INSTALL UNSTABLE VERSION"
apt-get install $aptargs texlive-full
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages

echo "=== START INSTALL DIST UPGRADE"
apt-get dist-upgrade $aptargs

echo "=== END"
