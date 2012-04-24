#!/bin/sh

aptargs="--assume-yes --allow-unauthenticated --no-install-recommends"

echo "=== TeX Live Test System ==="
echo "=== Test Overwrite: dist-upgrade/overwrite texlive-full from sid to test ==="
echo ""

echo "=== START INSTALL UNSTABLE VERSION"
apt-get install $aptargs texlive-full
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages

echo "=== START INSTALL DIST UPGRADE"
apt-get -o Dpkg::Options::="--force-overwrite" dist-upgrade $aptargs

echo "=== END"
