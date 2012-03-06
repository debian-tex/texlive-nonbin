#!/bin/sh
echo "=== TeX Live Test System ==="
echo "=== Test sid upgrade: dist-upgrade texlive from sid to test ==="
echo ""
find /etc/texmf -type f | sort > /pool/texmf-conffiles-2009
echo "deb file:/ pool/" >> /etc/apt/sources.list
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
echo "=== START INSTALL TEST VERSION"
apt-get dist-upgrade --allow-unauthenticated --assume-yes
find /etc/texmf -type f | sort > /pool/texmf-conffiles-2012
for i in $(find /tmp -name fmtutil\.\* -o -name updmap\.\*) ; do
  echo $i
  cat $i
  echo "=================="
done
echo "=== END"
