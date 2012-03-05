#!/bin/sh
echo "=== TeX Live Test System ==="
echo "=== Test 3: dist-upgrade texlive-full from sid to test ==="
echo ""
echo "=== START INSTALL UNSTABLE VERSION"
apt-get install --allow-unauthenticated --assume-yes texlive-full
find /etc/texmf -type f > /pool/texmf-conffiles-2009
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
echo "=== START INSTALL DIST UPGRADE"
apt-get dist-upgrade --allow-unauthenticated --assume-yes
find /etc/texmf -type f > /pool/texmf-conffiles-2012
echo "=== END"
