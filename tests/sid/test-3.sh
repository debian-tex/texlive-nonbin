#!/bin/sh
echo "=== TeX Live Test System ==="
echo "=== Test 3: dist-upgrade texlive-full from sid to test ==="
echo ""
aptargs="--without-recommends --assume-yes -o Aptitude::CmdLine::Ignore-Trust-Violations=yes"
echo "=== START INSTALL UNSTABLE VERSION"
aptitude install $aptargs texlive-full
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
echo "=== START INSTALL DIST UPGRADE"
aptitude dist-upgrade $aptargs
echo "=== END"
