#!/bin/sh
echo "=== TeX Live Test System ==="
echo "=== Test testing upgrade: dist-upgrade texlive from testing to test ==="
aptargs="--without-recommends --assume-yes -o Aptitude::CmdLine::Ignore-Trust-Violations=yes"
echo "=== START INSTALL TESTING VERSION"
aptitude install $aptargs texlive
find /etc/texmf | sort > /pool/testing-test-1-files-pre
echo ""
echo "deb http://ftp.nara.wide.ad.jp/debian/ sid main" > /etc/apt/sources.list
echo "deb file:/ pool/" >> /etc/apt/sources.list
aptitude update $aptargs
echo "=== START INSTALL TEST VERSION"
aptitude dist-upgrade $aptargs
find /etc/texmf | sort > /pool/testing-test-1-files-post
for i in $(find /tmp -name fmtutil\.\* -o -name updmap\.\*) ; do
  echo $i
  cat $i
  echo "=================="
done
echo "=== END"
