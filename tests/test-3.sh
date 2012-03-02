#!/bin/sh
echo "=== TeX Live Test System ==="
echo "=== Test 3: dist-upgrade texlive-full from sid to test ==="
echo ""
echo "=== START INSTALL UNSTABLE VERSION"
apt-get install --allow-unauthenticated --assume-yes texlive-full
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
echo "=== START INSTALL DIST UPGRADE"
apt-get dist-upgrade --allow-unauthenticated --assume-yes
echo "=== END"
