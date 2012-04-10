#!/bin/sh

aptargs="--assume-yes --allow-unauthenticated --no-install-recommends"

echo "=== TeX Live Test System ==="
echo "=== Test 4: dist-upgrade texlive from sid to test ==="
echo ""

echo "=== START INSTALL UNSTABLE VERSION"
apt-get install $aptargs texlive
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages

echo "=== START INSTALL TEST VERSION"
apt-get dist-upgrade $aptargs

echo "=== END"
