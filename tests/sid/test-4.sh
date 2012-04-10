#!/bin/sh
echo "=== TeX Live Test System ==="
echo "=== Test 4: dist-upgrade texlive from sid to test ==="
echo ""
aptargs="--without-recommends --assume-yes -o Aptitude::CmdLine::Ignore-Trust-Violations=yes"
echo "=== START INSTALL UNSTABLE VERSION"
aptitude install $aptargs texlive
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
echo "=== START INSTALL TEST VERSION"
aptitude dist-upgrade $aptargs
echo "=== END"
