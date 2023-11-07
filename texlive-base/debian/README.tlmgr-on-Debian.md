TeX Live Manager (tlmgr) on Debian
==================================

Rationale
---------

The TeX Live Manager (tlmgr) is the main configuration and package
management program in *upstream* TeX Live. Thus, the Debian TeX
Team has often received requests for providing `tlmgr` in Debian.

Since package management (installation, update, ...) is the responsability
of APT (apt, apt-get, ...), `tlmgr` *cannot* interfere with it, but uses
the "TeX Live Manager User Mode" instead.

For details concerning the User Mode, see https://tug.org/texlive/doc/tlmgr.html#USER-MODE

Warning
-------

`tlmgr` on Debian automatically switches to user mode. Consequences of this are:

- an initial setup step is necessary (see the documentation)
- packages will be installed into `TEXMFHOME` which normally is `$HOME/texmf`
- packages installed into `TEXMFHOME` will override system-wide installed 
  packages, that means a later system update will **not** be seen by TeX
- not all packages can be installed using the user mode, see the above link
  for details

We strongly recommend **not** to use the TeX Live Manager user mode on Debian.
If you are using it despite the warnings, be prepared to fix your own TeX system.

If you want the full power of TeX Live Manager, we recommend installing
TeX Live from upstream https://tug.org/texlive/quickinstall.html
See also "Integrating vanilla TeX Live with Debian" here https://tug.org/texlive/debian.html

