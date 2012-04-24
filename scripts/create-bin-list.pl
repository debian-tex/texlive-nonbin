#!/usr/bin/perl
#

use strict;

my $opt_master;

my ($mydir,$mmydir);
($mydir = $0) =~ s,/[^/]*$,,;
if ($mydir eq $0) { $mydir = `pwd` ; chomp($mydir); }
if (!($mydir =~ m,/.*,,)) { $mmydir = `pwd`; chomp($mmydir); $mydir = "$mmydir/$mydir" ; }


use Getopt::Long;

GetOptions (
			"master=s" => \$opt_master,	# location of Master
	);
 
use File::Basename;
use File::Copy;
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use Cwd;

our $Master;

if (!($opt_master =~ m,^/.*$,,)) {
	$Master = `pwd`;
	chomp($Master);
	$Master .= "/$opt_master";
} else {
	$Master = $opt_master;
}

#
# put Master/Tools/ into the include path to find TeX Live perl modules
#
unshift (@INC, "$Master/tlpkg");
#
# these we can only load now that we have correctly set the path to Master
#
require TeXLive::TLPDB;

&main(@ARGV);

1;


sub main {
	my $tlpdb = TeXLive::TLPDB->new(root => "$Master");
	die "Cannot load tlpdb!" unless defined($tlpdb);
	my $d = "$Master/bin/i386-linux";
	opendir (DIR, $d) || die "opendir($d) failed: $!";
	my @dirents = readdir (DIR);
	closedir (DIR) || warn "closedir($d) failed: $!";
	my @binfiles;
	for my $dirent (@dirents) {
		next if $dirent =~ /^\.(\.|svn)?$/;  # ignore . .. .svn
		push @binfiles, $dirent;
	}
	my %tlname;
	my %srcpkg;
	my $cfgfile = "./all/debian/tpm2deb.cfg";
	open(CFGFILE,"<$cfgfile") or die "Cannot open $cfgfile: $!";
	while (<CFGFILE>) {
		chomp;
		if (m/^name;([^;]*);([^;]*);([^;]*)$/) {
			$tlname{$1} = $2;
			$srcpkg{$1} = $3;
			next;
		}
	}
	for my $f (@binfiles) {
		my @ret = $tlpdb->find_file("bin/i386-linux/$f");
		if ($#ret < 0) {
			die "file not found: bin/i386-linux/$f";
		} elsif ($#ret > 0) {
			die "file containend in more packages: @ret";
		} else {
			my $p = $ret[0];
			$p =~ s/:.*$//;
			$p =~ s/\.i386-linux$//;
			for my $c ($tlpdb->collections) {
				for my $d ($tlpdb->get_package($c)->depends) {
					if ($d eq $p) {
						print "$f $p $c ";
						if (defined($tlname{$c})) {
							print "$tlname{$c} $srcpkg{$c}\n";
						} else {
							print "unknown unkown\n";
						}
					}
				}
			}
			#print "found bin/i386-linux/$f in $p\n";
		}
	}
}

### Local Variables:
### perl-indent-level: 4
### tab-width: 4
### indent-tabs-mode: t
### End:
# vim:set tabstop=4: #
