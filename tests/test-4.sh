#!/bin/sh
echo "=== TeX Live Test System ==="
echo "=== Test 4: dist-upgrade texlive from sid to test ==="
echo ""
echo "=== START INSTALL UNSTABLE VERSION"
apt-get install --allow-unauthenticated --assume-yes texlive       # 2007
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
echo "=== START INSTALL TEST VERSION"
apt-get dist-upgrade --allow-unauthenticated --assume-yes
echo "=== END"
