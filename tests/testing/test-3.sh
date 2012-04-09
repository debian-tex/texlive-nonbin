#!/bin/sh
echo "=== TeX Live Test System ==="
echo "=== Test testing upgrade: dist-upgrade ptex-bin from testing to test ==="
apt-get install --allow-unauthenticated --assume-yes ptex-bin
find /etc/texmf | sort > /pool/testing-test-3-files-pre
echo ""
echo "deb http://ftp.nara.wide.ad.jp/debian/ sid main" > /etc/apt/sources.list
echo "deb file:/ pool/" >> /etc/apt/sources.list
apt-get --allow-unauthenticated --assume-yes update
echo "=== START INSTALL TEST VERSION"
apt-get dist-upgrade --allow-unauthenticated --assume-yes
find /etc/texmf | sort > /pool/testing-test-3-files-post
for i in $(find /tmp -name fmtutil\.\* -o -name updmap\.\*) ; do
  echo $i
  cat $i
  echo "=================="
done
echo "=== END"
