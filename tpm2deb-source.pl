#!/usr/bin/perl
#
# tpm2deb-source.pl
# machinery to create debian packages from TeX Live depot
# (c) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012 Norbert Preining
#
# configuration is done via the file tpm2deb.cfg
# 

use strict;
no strict 'refs';
# use warnings;
# no warnings 'uninitialized';

my $opt_master;
our $opt_debug;
our $opt_nosrcpkg;
our $opt_noremove;
my $oldsrcdir;

BEGIN {
	unshift (@INC, "./all/debian");
}

my ($mydir,$mmydir);
($mydir = $0) =~ s,/[^/]*$,,;
if ($mydir eq $0) { $mydir = `pwd` ; chomp($mydir); }
if (!($mydir =~ m,/.*,,)) { $mmydir = `pwd`; chomp($mmydir); $mydir = "$mmydir/$mydir" ; }


$opt_debug = 0;
$opt_nosrcpkg = 0;
$opt_noremove = 0;
$oldsrcdir = "./src";

use Getopt::Long;
use File::Spec;

GetOptions ("debug!", 	# debug mode
			"nosrcpkg!",			# dont build source package
			"noremove!",			# dont remove build dir
			"master=s" => \$opt_master,	# location of Master
			"oldsource=s" => \$oldsrcdir	# use old source
	);
 

#use Strict;
use File::Basename;
use File::Copy;
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use Cwd;
use tpm2debcommon ;


my $changelog = "";
my $changelogversion = "";
my $changelogextraversion = "";
my $changelogrevision = "";
my $changelogdistribution = "";
my $allowed_dists = "(unstable|UNRELEASED|sarge-backports|etch-backports|stable-security|experimental)";


our $Master;

if (defined($opt_master)) {
	$Master = $opt_master;
}

if (!($opt_master =~ m,^/.*$,,)) {
	$Master = `pwd`;
	chomp($Master);
	$Master .= "/$opt_master";
} else {
	$Master = $opt_master;
}


File::Basename::fileparse_set_fstype('unix');


&main(@ARGV);

1;


####################################################################
#
# PART 0: The main() function
#
####################################################################

# variables needed outside of main
my $version;
my $revision;
my $extraversion;
my $date;
my $arch;
my $shortl;

sub setup_search_path_and_load {
	unshift (@INC, "$Master/tlpkg");
	require TeXLive::TLPDB;
	require TeXLive::TLUtils;
	print "Master = $Master\n";
	$::opt_verbosity = 1;
	$::tlpdb = TeXLive::TLPDB->new(root => "$Master");
	die "Cannot load tlpdb!" unless defined($::tlpdb);
	initialize_config_file_data("all/debian/tpm2deb.cfg");
	use Data::Dumper;
	#print Dumper(\%Config);
	build_data_hash();
	#print Dumper(\%TeXLive);
	check_consistency();
}

sub main {
	my ($cmd,@packages) = @_;
	$arch = "all";
	if ("$cmd" eq "make-orig-tar") {
		die "Need path to tlnet for orig building, specify with --master"
			if (! $opt_master);
		$Master = $opt_master;
		setup_search_path_and_load();
	}
	foreach my $package (@packages) {
		# 
		# various variables have to be set
		#
		$arch = get_arch($package);
		print "Working on $package, arch=$arch\n";
		if ("$cmd" eq "make-deb-source") {
			undef $::tlpdb;
			undef %TeXLive;
			undef %Config;
			make_deb_source($package);
		} elsif ("$cmd" eq "make-orig-tar") {
			read_changelog($package);
			$version = "$changelogversion$changelogextraversion";
			$revision = $changelogrevision;
			make_orig_tar($package);
		} else {
			print "cmd >$cmd< undefined!\n";
		}
	}
}


sub read_changelog {
	my ($package) = @_;

# 	print "entering read_changelog: $mydir/$package/debian/changelog\n";
# 	myopen(CL, "<$mydir/$package/debian/changelog") || die("Cannot open $mydir/$package/debian/changelog");;
 	open(CL, "<$mydir/$package/debian/changelog") || die("Cannot open $mydir/$package/debian/changelog");;
	my @lines = <CL>;
	close(CL);
# 	print "lines=@lines\n\n";

	my $dataline = "";
	$extraversion = "";
	$version = "";
	$revision = "";
	$date = "";

	foreach my $line (@lines) {
		print "changelog header=$line...\n";
		$line =~ m/^#/ && next;
		$line =~ m/^\s*$/ && next;
		# now we should have the first/top line, break out
		if ($line =~ m/^$package \(([^-]*)-(\S*)\) $allowed_dists; urgency=/) {
			$changelogversion = "$1";
			$changelogrevision = "$2";
			print "changelog version: $changelogversion-$changelogrevision\n";
			return;
		} else {
			print STDERR "$line\n";
			die("cannot parse changelog file $package.changelog\n Allowed dists:\n$allowed_dists");
		}
	}
}


#
# make_orig_tar
#
# Build the .orig.tar.gz from the perforce depot
#
sub make_orig_tar {
	# my function
	sub unpack_package {
		my ($pkg, $dest) = @_;
		if ($TeXLive{'binary'}{$pkg}{'relocated'}) {
			$dest .= "/texmf-dist";
		}
		File::Path::mkpath($dest);
		if (-r "$Master/archive/$pkg.tar.xz") {
			print "$pkg: run ";
			`tar -C $dest -xf $Master/archive/$pkg.tar.xz`;
		}
		if (-r "$Master/archive/$pkg.doc.tar.xz") {
			print "doc ";
			`tar -C $dest -xf $Master/archive/$pkg.doc.tar.xz`;
		}
		if (-r "$Master/archive/$pkg.source.tar.xz") {
			print "src";
			`tar -C $dest -xf $Master/archive/$pkg.source.tar.xz`;
		}
		print "\n";
	}
	sub copy_unpack_included_packages {
		my ($binpkg, $dest) = @_;
		my @packs = @{$TeXLive{'binary'}{$binpkg}{'includedpackages'}};
		for my $p (@packs) {
			unpack_package($p, $dest);
		}
	}
	# real start
	my ($src_package) = @_;
	my $foo;
	my $tmpdir = "${src_package}-${version}";
	my $debdest = "$tmpdir/debian";

	# don't regenerate an already existing tarball
	if ( -f "${src_package}_${version}.orig.tar.gz" ||
	     -f "${src_package}_${version}.orig.tar.xz") {
		print "${src_package}_${version}.orig.tar.(gz|xz) already exists, skipping.\n";
		return 0;
	}

	my $texlivedest = "$tmpdir";
	#
	# if $changelogrevision > 1 then bail out, we are not allowed to
	# build a new source!
	#
	if (1 lt $changelogrevision && ! ((my $tmprevision = $changelogrevision) =~ /1~/) ) {
		printf STDERR "ERROR ERROR ERROR\nYou are not allowed to generate a new source for revisions greater than 1!\nPlease specify the the location of the old sources with --oldsource=location\nExiting!\n";
		exit 1;
	}
	#
	# we are building a complete new package!
	# binfiles are always ignored because they are build from a different 
	# package
	# 
	my $types = "RunFiles DocFiles SourceFiles";
	#
	$opt_debug && print STDERR "Working on a source package!\n";
	foreach my $coll (@{$TeXLive{'source'}{$src_package}{'binary_packages'}}) {
		copy_unpack_included_packages($coll, $texlivedest);
	}
	# remove all saved tlpobj, we use the one we parse out
	`rm -rf \"$texlivedest/texmf-dist/tlpkg/tlpobj/\"`;
	`rm -rf \"$texlivedest/tlpkg/tlpobj/\"`;
	# remove blacklisted files, don't care if they were actually installed
	for my $f (@{$TeXLive{'all'}{'file_blacklist'}}) {
		`rm -f \"$texlivedest/$f\"`;
	}
	for my $f (@{$TeXLive{'all'}{'dir_blacklist'}}) {
		`rm -rf \"$texlivedest/$f\"`;
	}
	# remove those files that should not appear in the .orig but might still be installed
	for my $f (@{$TeXLive{'all'}{'notinorig'}}) {
		`rm -f \"$texlivedest/$f\"`;
	}
	# remove binary files
	`rm -rf \"$texlivedest/bin\"`;
	#
	# these files should not be here, they are installed by texlive.infra
	`rm -rf \"$texlivedest/tlpkg/installer/xz\"`;
	`rm -rf \"$texlivedest/tlpkg/installer/lz4\"`;
	#
	# necessary for media detection!
	&mkpath("$texlivedest/texmf-dist/web2c");
	# 
	# copy the files necessary for tpm2deb.pl from the Tools directory
	#
	&mkpath("$texlivedest/tlpkg");
	system("cp -a $Master/tlpkg/texlive.tlpdb $Master/tlpkg/TeXLive $texlivedest/tlpkg") == 0
		or die("Cannot copy necessary tlpkg file");
	#
	# make everything writeable!
	#
	system("chmod -R u+w $tmpdir") == 0
	    or die("Cannot set permissions on $tmpdir");
	#
	# and remove x bits from all files under Master/texmf-dist
	# but since this would make essential scripts in web2c (makeupd etc) not executable,
	# we exclude texmf-dist/web2c and texmf-dist/texconfig for now
	# MORE SAFE: disable this completely ...
	#if (-d "$texlivedest/texmf-dist") {
	#	system("find $texlivedest/texmf-dist/ -path $texlivedest/texmf-dist/web2c -prune -o -path $texlivedest/texmf-dist/texconfig -prune -o -type f -print0 | xargs -0 chmod -x") == 0
	#	    or die("Cannot remove unwanted execution permissions");
	#}
	# remove any git directories
	system("find $texlivedest -name '.git' | xargs rm -rf") == 0
		or die("Error while removing git directories");
	#
	# make the original source package
	#
	system("tar -cf - $tmpdir | xz > ${src_package}_${version}.orig.tar.xz") == 0
	    or die("Error creating orig.tar.xz");
	if (!$opt_debug && !$opt_noremove) { system("rm -rf $tmpdir"); }
}

sub create_license_file {
	my ($sourcepkg, $texlivedest) = @_;
	open FOO, ">$texlivedest/debian/Licenses.packages" or 
		die "Cannot open $texlivedest/debian/Licenses.packages: $!";
	print FOO "Licenses for source package $sourcepkg\n\n";
	my %allpacks;
	foreach my $coll (@{$TeXLive{'source'}{$sourcepkg}{'binary_packages'}}) {
		for my $p (@{$TeXLive{'binary'}{$coll}{'includedpackages'}}) {
			$allpacks{$p} = 1;
		}
	}
	chdir $texlivedest or die "Can't chdir to $texlivedest: $!";
	print "mydir/texlivedest = $mydir/$texlivedest\n";
	for my $p (sort keys %allpacks) {
		my $tlp = $::tlpdb->get_package($p);
		$tlp->replace_reloc_prefix;
		my @filelist;
		push @filelist, $tlp->runfiles;
		push @filelist, $tlp->docfiles;
		push @filelist, $tlp->srcfiles;
		my $lic = exists $tlp->cataloguedata->{'license'} ?
			$tlp->cataloguedata->{'license'} : "";
		my @files_dirs = TeXLive::TLUtils::collapse_dirs(grep { -r $_ } @filelist);
		print FOO "$p: $lic\n";
		for (@files_dirs) {
			s!^$mydir/$texlivedest/!!;
			if (-d $_) { print FOO "$_/*\n"; }
			else { print FOO "$_\n"; }
		}
	}
	chdir ($mydir);
	close(FOO);
}

#
# create_override_file
#
sub create_override_file {
	my ($package,$sourcepkg,$debdest,@locont) = @_;
	my @binlines;
	my @sourcelines;
	foreach (@locont) {
		if (m/^(\S*)#/) {
			next;
		} elsif (m/^(\S*) source: /) {
			if ($1 eq $sourcepkg) {
				push @sourcelines, $_;
			}
		} elsif (m/^(\S*): /) {
			if ($1 eq $package) {
				push @binlines, $_;
			}
		} else {
			push @binlines, "$package: $_";
		}
	}
	if ($#binlines >= 0) {
 		open(BINOVER,">$debdest/$package.lintian-overrides") 
		    or die("Cannot open $debdest/$package.lintian-overrides");
		foreach (@binlines) {
			print BINOVER $_;
		}
		close(BINOVER);
	}
	if ($#sourcelines >= 0) {
		mkpath("$debdest/source");
 		open(SOURCEOVER,">$debdest/source/lintian-overrides") 
		    or die("Cannot open $debdest/source/lintian-overrides");
		foreach (@sourcelines) {
			print SOURCEOVER $_;
		}
		close(SOURCEOVER);
	}
}

#
# make_deb_source
#
# We have to build a `real' debian package with .orig.tar.xz and a diff
# file. For this we start by putting the necessary files from the texmf trees
# into some subdirectory, and create the rest of the files via a diff
#
sub make_deb_source {
	my ($package) = @_;
	if ($package eq 'all') {
		foreach my $p (@{$TeXLive{'all'}{'sources'}}) {
			make_deb_source($p);
		}
		return 0;
	}
	my $foo;
	$arch = get_arch($package);
	read_changelog($package);
	$version = "$changelogversion$changelogextraversion";
	$revision = $changelogrevision;
	print "PACKAGE=$package ARCH=$arch VERSION=$version REVISION=$revision\n";
	# check for different places of old sources
	my $sourcedone = 0;
	my $oldorig;
	for my $t ("${package}_${version}.orig.tar.gz",
	           "./${package}_${version}.orig.tar.xz",
			   "$oldsrcdir/${package}_${version}.orig.tar.gz",
			   "$oldsrcdir/${package}_${version}.orig.tar.xz") {
	  if (-r $t) {
	  	$oldorig = $t;
		$sourcedone = 1;
		last;
	  }
	}
	#if (-r "./${package}_${version}.orig.tar.gz") {
	#	$oldorig = "./${package}_${version}.orig.tar.gz";
	#	$sourcedone = 1;
	#} elsif (-r "$oldsrcdir/${package}_${version}.orig.tar.gz") {
	#	$oldorig = "$oldsrcdir/${package}_${version}.orig.tar.gz";
	#	system("cp $oldorig .") == 0 or die("Cannot cp $oldorig .!\n");
	#	$sourcedone = 1;
	#}
	if ($sourcedone) {
		print "Reusing $oldorig file for source package building!\n";
		system("tar -xf $oldorig") == 0 or die("Error untarring");
		if ($package eq "texlive-extra") {
		  my $extraorig = $oldorig;
		  $extraorig =~ s/\.orig\./\.orig-tex4ht\./;
		  system("mkdir ${package}-${version}/tex4ht && tar -C ${package}-${version}/tex4ht -xf $extraorig") == 0 or die("Cannot untar $extraorig, missing?");
		}
	} else {
		die("Please create a .orig.tar.xz first!\n");
	}
	my $tmpdir = "${package}-${version}";
	mkpath($tmpdir);
	$opt_debug && print STDERR "tmpdir = $tmpdir\n";
	my $debdest = "$tmpdir/debian";
	# $texlivedest = "$tmpdir/Master";
	my $texlivedest = "$tmpdir";
	#
	# setup all the stuff
	$Master = File::Spec->rel2abs($tmpdir);
	setup_search_path_and_load();
	# dpkg-source cannot handle new symlinks
	my $symlinklist = `find $mydir/all/ -type l`;
	die("Symlinks $symlinklist detected in $mydir/all") if $symlinklist;
	
	system ("cp -a $mydir/all/* $tmpdir/") == 0
	    or die("Error copying common files");
	system ("rm  $tmpdir/debian/rules.in") == 0
	    or die("Error removing rules.in");
	system ("find $tmpdir/ -name .git -type d -print0 | xargs -0 rm -rf") == 0 
	    or die("Error removing .git directories");

	system ("cp -a $mydir/$package/* $tmpdir/") == 0
	    or die("Error copying package-specific files");

	my @metapackages;
	my @normalpackages;
	foreach my $foo (@{$TeXLive{'source'}{$package}{'binary_packages'}}) {
		$opt_debug && print STDERR "DEBUG: $foo in @{$TeXLive{'all'}{'meta_packages'}}\n";
		if (ismember($foo,@{$TeXLive{'all'}{'meta_packages'}})) {
			push @metapackages, $foo;
		} else {
			push @normalpackages, $foo;
		}
	}
	system (qq{m4 -D_srcpackage_=$package -D_binpackages_="@normalpackages" -D_metapackages_="@metapackages" $mydir/all/debian/rules.in > $debdest/rules}) == 0
	    or die("Error creating debian/rules");;
	system(qq{chmod ugo+x $debdest/rules}) == 0
	    or die("Cannot change permissions of $debdest/rules");;

	make_deb_control($package,"$debdest/control");
	system ("find $tmpdir/ -name .git -type d -print0 | xargs -0 rm -rf") == 0 
	    or die("Error removing .git directories");
	# 
	# lintian override files
	#
	open(OVERRIDE,"<$mydir/all/debian/lintian.override") 
	    or die("Cannot open $mydir/all/debian/lintian.override");
	my @locont = <OVERRIDE>;
	close(OVERRIDE);
	foreach my $coll (@{$TeXLive{'source'}{$package}{'binary_packages'}}) {
		create_override_file($coll,$package,$debdest,@locont);
	} 
	create_license_file($package, $texlivedest);
	# 
	# Building the source package
	#
	print STDERR "Building the package with dpkg-source\n";
	system ("chmod u+w $tmpdir/debian/*") == 0
	    or die("Error adjusting permissions of $tmpdir/debian");
	if (!$opt_nosrcpkg) {
	    my $dpkg_cmdline = "dpkg-source -b $tmpdir" . ($opt_debug ? "" : " 2>/dev/null");
	    system ( $dpkg_cmdline) == 0
		or die("Cannot pack ${package}_${version}!\n");
	}
	if (!$opt_debug && !$opt_noremove) { system("rm -rf $tmpdir"); }
}

#
# make_deb_control
#

sub make_deb_control {
	# my functions
	sub makeuniq {
		my ($arrayref) = @_;
		my %bla;
		foreach (@$arrayref) {
			$bla{$_} = 1;
		}
		@$arrayref = keys(%bla);
	}  
	sub unversioned_tetex_conflict {
		my (@AllConflicts) = @_;
		my $ret = 1;
		foreach my $conflict (@AllConflicts) {
			if ($conflict =~ m/^[[:space:]]*tetex-(base|extra|bin|source)[^(]*$/) {
				return(1);
			}
		}
		return(0);
	}
	# real start
	my ($package, $destfname) = @_;
	my $foo;
	open(CONTROL,">$destfname") || die("Cannot open $destfname!\n");
	print CONTROL "Source: $package\n";
	print CONTROL "Section: ",
		defined($TeXLive{'source'}{$package}{'section'}) ? "$TeXLive{'source'}{$package}{'section'}" : "$TeXLive{'all'}{'section'}",
		"\n";
	print CONTROL "Priority: ",
		defined($TeXLive{'source'}{$package}{'priority'}) ? $TeXLive{'source'}{$package}{'priority'} : "$TeXLive{'all'}{'priority'}",
		"\n";
	print CONTROL "Maintainer: ",
		defined($TeXLive{'source'}{$package}{'maintainer'}) ? $TeXLive{'source'}{$package}{'maintainer'} : "$TeXLive{'all'}{'maintainer'}",
		"\n";
	print CONTROL "Uploaders: ",
		defined($TeXLive{'source'}{$package}{'uploaders'}) ? $TeXLive{'source'}{$package}{'uploaders'} : "$TeXLive{'all'}{'uploaders'}",
		"\n";
	if (defined($TeXLive{'source'}{$package}{'build_dep'})) {
		print CONTROL "Build-Depends: $TeXLive{'source'}{$package}{'build_dep'}\n";
	}
	if (defined($TeXLive{'source'}{$package}{'build_dep_indep'})) {
		print CONTROL "Build-Depends-Indep: $TeXLive{'source'}{$package}{'build_dep_indep'}\n";
	}
	print CONTROL "Standards-Version: ",
		defined($TeXLive{'source'}{$package}{'standards'}) ? "$TeXLive{'source'}{$package}{'standards'}" : "$TeXLive{'all'}{'standards'}",
		"\n";
	print CONTROL "Homepage: http://www.tug.org/texlive/\n";
	#
	# now start the individual packages
	#
	my @pkglist = ();
	foreach my $pkg (@{$TeXLive{'source'}{$package}{'binary_packages'}}) {
		my $type_of_package = 'binary';
		if (defined($TeXLive{'mbinary'}{$pkg})) {
			$type_of_package = 'mbinary';
		}
		my %lists = %{&get_all_files($pkg)};
		my $title = $TeXLive{$type_of_package}{$pkg}{'title'};
		my @lop = ();
		my $contains_binaries = 0;
		# check that some packages are actually included before adding
		# intro text below to the control file
		foreach my $p (@{$TeXLive{$type_of_package}{$pkg}{'includedpackages'}}) {
			my $subtype = $TeXLive{'binary'}{$p}{'type'};
			if ($p =~ m/\.i386-linux$/) {
				$contains_binaries = 1 ;
			}
			if (($subtype eq "Package") || ($subtype eq "Documentation")) {
				push @lop, $p;
			}
		}
		my $description = '';
		if (defined($TeXLive{$type_of_package}{$pkg}{'description'})) {
			$description = $TeXLive{$type_of_package}{$pkg}{'description'};
		}
		print CONTROL "\nPackage: $pkg\n";
		if (defined($TeXLive{$type_of_package}{$pkg}{'section'})) {
			print CONTROL "Section: $TeXLive{$type_of_package}{$pkg}{'section'}\n";
		}
		if (defined($TeXLive{$type_of_package}{$pkg}{'priority'})) {
			print CONTROL "Priority: $TeXLive{$type_of_package}{$pkg}{'priority'}\n";
		}
		print CONTROL "Architecture: $arch\n";
		# Multi-arch setup, see discussion at bug #792281
		print CONTROL "Multi-Arch: foreign\n";
		#
		my @AllDepends = @{$TeXLive{$type_of_package}{$pkg}{'depends'}};
		# in case that we have binaries included we add the dep
		# onto texlive-bin-$source
		if ($contains_binaries) {
			#my $binname = $package; # texlive-{base,extra,lang,doc}
			#$binname .= "-binaries";
			#push @AllDepends, $binname;
			push @AllDepends, "texlive-binaries";
		}
		push @AllDepends, '${misc:Depends}';
# 		if ($arch eq "any") {
# 			push (@AllDepends, '${shlibs:Depends}');
# 		}
		print CONTROL "Depends: ";
		makeuniq(\@AllDepends);
		my @finaldeps = ();
		foreach my $d (@AllDepends) {
			if ($d =~ m/^texlive[^ ]*$/) {
				# if we match a package name without a space, ie without a
				# correct version number, we add the respective source
				# package minimal version
				my $srcpkg = $TeXLive{'binary'}{$d}{'source_package'};
				push @finaldeps, "$d (>= $TeXLive{'source'}{$srcpkg}{'latest_version'})";
			} else {
				push @finaldeps, "$d";
			}
		}
		print CONTROL join(", ",sort @finaldeps), "\n";
		$opt_debug && print STDERR  "\nDependencies for $package: ", join(", ",@AllDepends), "\n";
		#
		# Conflicts
		#
		my @AllConflicts = @{$TeXLive{$type_of_package}{$pkg}{'conflicts'}};
		if ($#AllConflicts >= 0) {
			makeuniq(\@AllConflicts);
			print CONTROL "Conflicts: ", join(", ", sort @AllConflicts), "\n";
		}
		#
		# Recommends
		#
		my @AllRecommends = @{$TeXLive{$type_of_package}{$pkg}{'recommends'}};
		if ($#AllRecommends >= 0) {
			makeuniq(\@AllRecommends);
			print CONTROL "Recommends: ", join(", ", sort @AllRecommends), "\n";
		}
		#
		# Provides
		#
		my @AllProvides = @{$TeXLive{$type_of_package}{$pkg}{'provides'}};
		if ($#AllProvides >= 0) {
			makeuniq(\@AllProvides);
			print CONTROL "Provides: ", join(", ", sort @AllProvides), "\n";
		}
		#
		# Suggests
		#
		my @AllSuggests = @{$TeXLive{$type_of_package}{$pkg}{'suggests'}};
		if ($#AllSuggests >= 0) {
			makeuniq(\@AllSuggests);
			print CONTROL "Suggests: ", join(", ", sort @AllSuggests), "\n";
		}
		#
		# Replaces
		#
		my @AllReplaces = @{$TeXLive{$type_of_package}{$pkg}{'replaces'}};
		if ($#AllReplaces >= 0) {
			makeuniq(\@AllReplaces);
			print CONTROL "Replaces: ", join(", ", sort @AllReplaces), "\n";
		}
		#
		# Breaks
		#
		my @AllBreaks = @{$TeXLive{$type_of_package}{$pkg}{'breaks'}};
		if ($#AllBreaks >= 0) {
			makeuniq(\@AllBreaks);
			print CONTROL "Breaks: ", join(", ", sort @AllBreaks), "\n";
		}
		#
		print CONTROL "Description: TeX Live: $title\n";
		#
		my $rest = $description;
		$rest =~ s/\n/ /g;
		my @deslines = ();
		while ($rest ne '') {
			if (length($rest) <= 76) {
				push @deslines, $rest;
				last;
			}
			$rest =~ /^(.{1,76}\s+)([a-zA-Z0-9])/ms;
			push @deslines, $1;
			$rest = "$2$'";
		}
		my $firstline = 1;
		for my $l (@deslines) {
			if ($l =~ m/^\s*$/) {
				if ($firstline) { $firstline = 0; next; }
				print CONTROL " .\n";
			} else {
				# remove some leading whitespace
				$l =~ s/^\s*//;
				print CONTROL " $l\n";
			}
		}
		# old code!
		#my @deslines = split(/\n/, $description);
		#my $firstline = 1;
		#foreach my $l (@deslines) {
		#	if ($l =~ m/^\s*$/) {
		#		if ($firstline) { $firstline = 0; next; }
		#		print CONTROL " .\n";
		#	} else { 
		#		#$shortl = shortenline($l);
		#		#print CONTROL " $shortl\n";
		#		$shortl = $l;
		#		write CONTROL;
		#	}
		#}
		if ($#lop < 0) {
			next;
		}
		print CONTROL " .\n" if ($description);
		print CONTROL " This package includes the following CTAN packages:\n";
		# make each package its own paragraph, to help translators
		foreach my $p (@lop) {
			next if is_blacklisted($p,$pkg);
			# ignore split out arch packages
			next if ($p =~ m/\.i386-linux$/);
			my $tit = $TeXLive{'binary'}{$p}{'title'};
			chomp($tit);
			# make each package its own paragraph, to help translators
			# thus, no need for a list, don't add initial space!
			# # add an extra space at the beginning to have a real list
			# $shortl = " $p -- $tit";
		    print CONTROL " .\n";
			$shortl = "$p -- $tit";
			write CONTROL;
			#
		}
	}
	close CONTROL;
}


sub get_arch {
	my ($srcpackage) = @_;
	my $a = "all";
	if (defined($TeXLive{'source'}{$srcpackage}{'architecture'})) {
		$a = $TeXLive{'source'}{$srcpackage}{'architecture'};
	}
	return($a);
}

	

#####################################
#
# Formats
#
format CONTROL =
 ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
$shortl
.

### Local Variables:
### perl-indent-level: 4
### tab-width: 4
### indent-tabs-mode: t
### End:
# vim:set tabstop=4 noexpandtab: #
