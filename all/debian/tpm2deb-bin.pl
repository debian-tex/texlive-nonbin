#!/usr/bin/perl
#
# tpm2deb-bin.pl
# machinery to create debian packages from TeX Live depot
# (c) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012 Norbert Preining
#
# configuration is done via the file tpm2deb.cfg
#

BEGIN {   # get our other local perl modules.
	unshift (@INC, "./debian");
	unshift (@INC, "./tlpkg");
}

use strict "vars";
# use strict "refs"; # not possible with merge_into
use warnings;
no warnings 'once';
no warnings 'uninitialized';

#use Strict;
use Getopt::Long;
use File::Basename;
use File::Copy;
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use Cwd;

use TeXLive::TLPDB;
use TeXLive::TLPOBJ;

# use Data::Dumper;


my $debdest;
my $basedir;
my $bindest;
my $bincomponent = "/usr/bin";
my $rundest;
my $runcomponent = "/usr/share/texlive";
my $docdest;
my $doccomponent;
my $etcdest;
my $tmpdir;


#
# Configuration for destination of files
# DONT USER DOUBLE QUOTES; THESE VARIABLES HAVE TO GET REEVALUATED
# AFTER $tmpdir IS SET!!
#
my $sysdebdest = '$tmpdir/debian';
my $sysbasedir = '$debdest/$package';
my $sysbindest = '$basedir/usr/bin';
my $sysbincomponent = '/usr/bin';
my $sysrundest = '$basedir/usr/share/texlive';
my $sysruncomponent = '/usr/share/texlive';
my $sysdocdest = '$basedir/usr/share/doc/$package';
my $sysdoccomponent = '/usr/share/doc/$package';
my $sysetcdest = '$basedir/etc/texmf';

my $texmfdist = "texmf-dist";
my $opt_nosource=0;
my $optdestination="";
our $opt_onlyscripts=0;
my $opt_onlycopy=0;

our $opt_debug; #global variable
my $opt_master;
our $Master;
my $globalreclevel=1;

my $result = GetOptions ("debug!" => \$opt_debug, 	# debug mode
	"nosource!" => \$opt_nosource,			# don't include source files
	"master=s" => \$opt_master,	# location of Master
	"dest=s" => \$optdestination,	# where to write files
	"reclevel=i" => \$globalreclevel,	# recursion level
	"onlyscripts!" => \$opt_onlyscripts, # only create maintainer scripts
	"onlycopy!" => \$opt_onlycopy # no maintscripts, only copy files
	);

# Norbert, is $, intended here, or should it rather be m{/.*$}?
if (!($opt_master =~ m,/.*$,,)) {
	$Master = `pwd`;
	chomp($Master);
	$Master .= "/$opt_master";
} else {
	$Master = $opt_master;
}

my $startdir=getcwd();
chdir($startdir);
File::Basename::fileparse_set_fstype('unix');

use tpm2debcommon;

&main(@ARGV);

1;


sub main {
	my (@packages) = @_;
	my $arch = "all";
	# the following variable is used in the Tpm.pm module,
	# and should always be set to i386-linux, no matter what 
	# the real Debian architecture is
	$::tlpdb = TeXLive::TLPDB->new(root => "$Master");
	die "Cannot load tlpdb!" unless defined($::tlpdb);
	initialize_config_file_data("debian/tpm2deb.cfg");
	build_data_hash();
    #    use Data::Dumper;
	#    $Data::Dumper::Indent = 1;
    #    print Dumper(\%TeXLive);
    #    exit(1);
	check_consistency();
	foreach my $package (@packages) {
		# 
		# various variables have to be set
		#
		#$arch = get_arch($package);
		#print "Working on $package, arch=$arch\n";
		print "Working on $package\n";
		# determine variables used in all subsequent functions
		$opt_debug && print STDERR "Setting global vars\n";
		tl_set_global_vars($package);
		#
		# copy files etc.
		# 
		make_deb($package); #unless ($opt_onlyscripts);
		#
		# create the maintainer scripts
		#
		make_maintainer($package,$debdest) unless ($opt_onlycopy);
	}
}

#
# set global variables
#
sub tl_set_global_vars {
	my ($package) = @_;
	my $helper;
	if ($optdestination ne "") {
		$tmpdir = $optdestination;
	} else {
		$tmpdir = ".";
	}
	$opt_debug && print STDERR "tmpdir = $tmpdir\n";
	$helper="\$debdest = \"$sysdebdest\""; eval $helper;
	$helper="\$basedir = \"$sysbasedir\""; eval $helper;
	$helper="\$bindest = \"$sysbindest\""; eval $helper;
	$helper="\$rundest = \"$sysrundest\""; eval $helper;
	$helper="\$docdest = \"$sysdocdest\""; eval $helper;
	$helper="\$doccomponent = \"$sysdoccomponent\""; eval $helper;
	$helper="\$etcdest = \"$sysetcdest\""; eval $helper;
	$opt_debug && print STDERR "\nGlobal options:\n";
	if ($opt_debug) {
		print STDERR "debdest = $debdest\n";
		print STDERR "basedir = $basedir\n";
		print STDERR "bindest = $bindest\n";
		print STDERR "rundest = $rundest\n";
		print STDERR "docdest = $docdest\n";
		print STDERR "doccomponent = $doccomponent\n";
		print STDERR "etcdest = $etcdest\n";
	}
}

#
# tl_is_blacklisted <filename>
#
sub tl_is_blacklisted {
	my ($file) = @_;
	my $blacklisted = 0;
	foreach my $pat (@{$TeXLive{'all'}{'file_blacklist'}}) { 
		$blacklisted = 1 if ($file =~ m|^${pat}$|);
	}
	$opt_debug && $blacklisted && print STDERR "$file is blacklisted\n";
	return $blacklisted;
}

#
# make_deb_copy_to_righplace
#
# depends on global var $rundest
sub make_deb_copy_to_rightplace {
	my ($package,$listref) = @_;
	my %lists = %$listref;
	if (!$opt_nosource) {
		DOSFILE: foreach my $file (@{$lists{'SourceFiles'}}) {
			next DOSFILE if tl_is_blacklisted($file);
			my $finalfn = do_remap_and_copy($package,$file,$runcomponent);
			do_special($file,$finalfn);
		}
	}
	DORFILE: foreach my $file (@{$lists{'RunFiles'}}) {
		next DORFILE if tl_is_blacklisted($file);
		my $finalfn = do_remap_and_copy($package,$file,$runcomponent);
		do_special($file,$finalfn);
	}
	DODFILE: foreach my $file (@{$lists{'DocFiles'}}) {
		next DODFILE if tl_is_blacklisted($file);
		my $finalfn = do_remap_and_copy($package,$file,$runcomponent);
		do_special($file,$finalfn);
	}
	# simply ignore binfiles as we have to add the necessary deps
	#DOBFILE: foreach my $file (@{$lists{'BinFiles'}}) {
	#	$opt_debug && print STDERR "BINFILE: $file\n";
	#	next DOBFILE if tl_is_blacklisted($file);
	#	my $finalfn = do_remap_and_copy($package,$file,$bincomponent,'^bin/[^/]*/(.*)$','/usr/bin/$1');
	#	do_special($file,$finalfn);
	#}
	if ($package eq 'texlive-common') {
		&mkpath("$debdest/texlive-common/usr/share/texlive/tlpkg");
		mycopy("$Master/tlpkg/TeXLive","$debdest/texlive-common/usr/share/texlive/tlpkg/");
	}
}

#
# make_deb_execute_actions
#
# depends on global variable $globalreclevel
# FIXXME: could be divided in get_execute_actions and
# do_execute_actions, probably needs pass-by-reference if we don't
# want to use global vars.
sub make_deb_execute_actions {
	my ($package) = @_;
    my @Executes = get_all_executes($package,$globalreclevel);
	my @maplines = ();
	my @formatlines = ();
	my @languagelines = ();
	my $gotmapfiles = 0;
	my $firstlang =1;
	my %langhash = ();
	my %formathash = ();
	$opt_debug && print STDERR "Executes= @Executes\n";
	my %Job;
	for my $e (@Executes) {
		my ($what, $first, @rest) = split ' ', $e;
		my $instcmd;
		my $rmcmd;
		if ($what eq 'addMap') {
			push @maplines, "Map $first\n";
		} elsif ($what eq 'addMixedMap') {
			push @maplines, "MixedMap $first\n";
		} elsif ($what eq 'addKanjiMap') {
			push @maplines, "KanjiMap $first\n";
		} elsif ($what eq 'AddFormat') {
			my %r = TeXLive::TLUtils::parse_AddFormat_line(join(" ", $first, @rest));
			if (defined($r{"error"})) {
				die "$r{'error'}, package $package, execute $e";
			}
			my $mode = ($r{"mode"} ? "" : "#! ");
			if (defined($Config{'disabled_formats'}{$package})) {
				next if (ismember($r{'name'}, @{$Config{'disabled_formats'}{$package}}));
			}
			push @formatlines, "$mode$r{'name'} $r{'engine'} $r{'patterns'} $r{'options'}\n";
		} elsif ($what eq 'AddHyphen') {
			my %r = TeXLive::TLUtils::parse_AddHyphen_line(join(" ", $first, @rest));
			my $lline = "name=$r{'name'} file=$r{'file'} patterns=$r{'file_patterns'} lefthyphenmin=$r{'lefthyphenmin'} righthyphenmin=$r{'righthyphenmin'}";
			if (defined($r{'file_exceptions'})) {
				$lline .= " exceptions=$r{'file_exceptions'}";
			}
			my @syns;
			@syns = @{$r{"synonyms"}} if (defined($r{"synonyms"}));
			if ($#syns >= 0) {
				$lline .= " synonyms=" . join(",",@syns);
			}
			push @languagelines, "$lline\n";
		}
	}
	if ($#maplines >= 0) {
		open(OUTFILE, ">$debdest/$package.maps")
			or die("Cannot open $debdest/$package.maps");
		foreach (@maplines) { print OUTFILE; }
		close(OUTFILE);
	}
	if ($#formatlines >= 0) {
		open(OUTFILE, ">$debdest/$package.formats")
			or die("Cannot open $debdest/$package.formats");
		foreach (@formatlines) { print OUTFILE; }
		close(OUTFILE);
	}
	if ($#languagelines >= 0) {
		open(OUTFILE, ">$debdest/$package.hyphens")
			or die("Cannot open $debdest/$package.hyphens");
		foreach (@languagelines) { print OUTFILE; }
		close(OUTFILE);
	}
}

#
# make_deb
#
sub make_deb {
	# my function
	#
	# do_special ($originalfilename, $finaldestinationfilename)
	#
	# Do special actions as specified in the config file, like install info
	# etc
	our @SpecialActions = ();
	sub do_special {
		my ($origfn, $finalfn) = @_;
		our @SpecialActions;
		SPECIALS: foreach my $special (@{$TeXLive{'all'}{'special_actions_config'}}) {
			my ($pat, $act) = ($special =~ m/(.*):(.*)/);
			if ($origfn =~ m|$pat$|) {
				if ($act eq "install-info") {
					push @SpecialActions, "install-info:$origfn";
				} else {
					print STDERR "Unknown special action $act, terminating!\n";
					exit 1;
				}
			}
		}
	}
	# real start
	my ($package) = @_;
	my $type_of_package = 'binary';
	if (defined($TeXLive{'mbinary'}{$package})) {
		# this is a meta package!
		$type_of_package = 'mbinary';
	}
	my %lists = %{&get_all_files($package, $globalreclevel)};
	my $title = $TeXLive{$type_of_package}{$package}{'title'};
	my $description = $TeXLive{$type_of_package}{$package}{'description'};
	eval { mkpath($rundest) };
	if ($@) {
		die "Couldn't create dir: $@";
	}  
	if ($opt_debug) {
		print STDERR "SOURCEFILES: ", @{$lists{'SourceFiles'}}, "\n";
		print STDERR "RUNFILES: ", @{$lists{'RunFiles'}}, "\n";
		print STDERR "DOCFILES: ", @{$lists{'DocFiles'}}, "\n";
		print STDERR "BINFILES: ", @{$lists{'BinFiles'}}, "\n";
	}
	&mkpath($docdest);
	#
	# DO REMAPPINGS and COPY FILES TO DEST
	#
	make_deb_copy_to_rightplace($package,\%lists);
	#
	# EXECUTE ACTIONS
	#
	make_deb_execute_actions($package);
	#
	# Work on @SpecialActions
	#
	my @infofiles = ();
	foreach my $l (@SpecialActions) {
		my ($act, $fname) = ($l =~ m/(.*):(.*)/);
		if ($act eq "install-info") {
			push @infofiles, "$fname";
		} else {
			print STDERR "Unknown action, huuu, where does this come from: $act, exit!\n";
			exit 1;
		}
	}
	if ($#infofiles >=0) {
		open(INFOLIST, ">$debdest/$package.info")
		    or die("Cannot open $debdest/$package.info");
		foreach my $f (@infofiles) {
			print INFOLIST "$f\n";
		}
		close(INFOLIST);
	}
}

#
# make_maintainer
#
# create maintainer scripts. 
# This function uses global vars: $debdest
#
sub make_maintainer {
	sub merge_into {
		my ($source_fname, $target_fhandle) = @_;
		if (-e "$source_fname") {
			open(SOURCE,"<$source_fname")
			    or die("Cannot open $source_fname");
			while (<SOURCE>) { print $target_fhandle $_; }
			close(SOURCE);
		}
	}
	my ($package,$debdest) = @_;
	print "Making maintainer scripts for $package in $debdest...\n";
	&mkpath($debdest);
	# create debian/maintscript
	if ((-r "$debdest/$package.maintscript.dist") ||
	    ($#{$TeXLive{'binary'}{$package}{'remove_conffile'}} >= 0)) {
		open(MAINTHELP, ">$debdest/$package.maintscript")
			or die("Cannot open $debdest/$package.maintscript for writing");
		merge_into("$debdest/$package.maintscript.dist", MAINTSCRIPT);
		#
		# handling of conffile moves
		if ($#{$TeXLive{'binary'}{$package}{'remove_conffile'}} >= 0) {
			for my $conffile (@{$TeXLive{'binary'}{$package}{'remove_conffile'}}) {
				my $srcpkg = $TeXLive{'binary'}{$package}{'source_package'};
				my $oldversion = $TeXLive{'source'}{$srcpkg}{'old_version'};
				print MAINTHELP "rm_conffile $conffile $oldversion\n";
			}
		}
		close(MAINTHELP);
	}
	for my $type (qw/postinst preinst postrm prerm/) {
		$opt_debug && print STDERR "Handling $type ";
		if ((-r "$debdest/$type.pre") ||
			(-r "$debdest/$type.post") ||
			(-r "$debdest/$package.$type.pre") || 
			(-r "$debdest/$package.$type.post"))
		{
			open(MAINTSCRIPT, ">$debdest/$package.$type")
				or die("Cannot open $debdest/$package.$type for writing");
			print MAINTSCRIPT "#!/bin/sh -e\n";
			merge_into("$debdest/common.functions", MAINTSCRIPT);
			merge_into("$debdest/common.functions.$type", MAINTSCRIPT);
			merge_into("$debdest/$type.pre", MAINTSCRIPT);
			merge_into("$debdest/$package.$type.pre", MAINTSCRIPT);
			#
			# add debhelper stuff and post-parts.
			print MAINTSCRIPT "\n#DEBHELPER#\n";
			merge_into("$debdest/$package.$type.post", MAINTSCRIPT);
			merge_into("$debdest/$type.post", MAINTSCRIPT);
			print MAINTSCRIPT "exit 0\n";
			close MAINTSCRIPT;
		}
		$opt_debug && print STDERR " done.\n";
	}
}

#
# get_texmf_relpath
#
sub get_texmf_relpath {
	my ($filename) = @_;
	#$filename =~ s{texmf-dist}{texmf};
	#$filename =~ s{texmf-doc}{texmf};
	#$filename =~ s{texmf/}{};
	return $filename;
}

#
# do_remap_and_copy
#
# policy for mapping lines:
# ALL file names in the last field are:
# - either ABSOLUTE filenames in the sense of the final installation
#   example:
#     mapping;texmf/tex/generic/config/language.dat;link;/var/lib/texmf/tex/generic/config/language.dat
# - relative filenames in which case 
#         $texmfdist  =   /usr/share/texlive/texmf-dist
#   is prepended, eg:
#        mapping;texmf-dist/fonts/map/dvips/ibygrk/ibycus4.map;remap;fonts/source/public/ibygrk/ibycus4.map
#   in this case ibycus4.map is remapped to 
#     /usr/share/texlive/texmf-dist/fonts/source/public/ibygrk/ibycus4.map
#
# The filenames CAN contain backreferences to patterns:
# mapping;texmf[^/]*/doc/man/man(.*)/(.*);remap;/usr/share/man/man$1/$2
#
sub do_remap_and_copy {
	# my functions
	#
	# here the mapping from texlive pathes to debian pathes is done
	#
	sub make_destinationname {
		my ($path) = @_;
		#$path =~ s#^texmf-dist#$texmfdist#;
		#
		# we do map *ALL* files into $texmfdist, not only the dist files
		#
		#$path =~ s#^texmf/#$texmfdist/#;
		return("$path");
	}
	sub absolute_path {
		my ($inpath) = @_;
		if ($inpath =~ m,^/,) {
			# absolute path, just return it
			return ($inpath);
		} else {
			# relative path name add /usr/share/$texmfdist
			return ("$runcomponent/$texmfdist/$inpath");
		}
	}
	# real start
	my ($package,$file,$defaultpathcomponent,$finalremap,$finaldest) = @_;
	my $gotremapped = 0;
	my $returnvalue = "**NOTSET**";
	my $defaultdestname = make_destinationname($file);
	$opt_debug && print STDERR "DESTINATION NAME = $defaultdestname\n";

	MAPPINGS: foreach my $maplines (@{$TeXLive{'all'}{'filemappings'}}) {
		my ($pat, $dest) = ($maplines =~ m/(.*):(.*)/);
		if ($file =~ m|$pat$|) {
			$gotremapped = 1;
			my $act = $TeXLive{'all'}{'file_map_actions'}{$pat};
			my $supplieddestname;
			# this evaluation is NECESSARY since the last entries in the 
			# file mappings can contain back references to patterns in $pat!!!
			my $foo="\$supplieddestname = \"$dest\"";
			eval $foo;
			$supplieddestname = absolute_path($supplieddestname);
			$opt_debug && print STDERR "REMAP HIT f=$file\nsupplieddestname=$supplieddestname\npat=$pat\ndest=$dest\n";
			# if you add possible actions here, also add them to the list in tpm2deb.cfg
			if (($act eq "move") || ($act eq "config-move")) {
				# remap MOVES the file to the new position
				$opt_debug && print STDERR "remap\n";
				&mkpath(dirname("$basedir$supplieddestname"));
				mycopy("$Master/$file","$basedir$supplieddestname");
				$returnvalue = $supplieddestname;
			} elsif (($act eq "copy") || ($act eq "config-copy")) {
				$opt_debug && print STDERR "copy\n";
				# first install it into the normal path
				mycopy("$Master/$file","$basedir$defaultpathcomponent/$defaultdestname");
				# now the same as in remap/config-remap
				&mkpath(dirname("$basedir$supplieddestname"));
				mycopy("$Master/$file","$basedir$supplieddestname");
				$returnvalue = $supplieddestname;
			} elsif ($act eq "copy-move") {
				$opt_debug && print STDERR "copy-move\n";
				my ($configpath,$secondpath) = split(/,/ , $supplieddestname);
				$opt_debug && print STDERR "installing into $configpath and $secondpath\n";
				# first install it into the config path
				&mkpath(dirname("$basedir$configpath"));
				mycopy("$Master/$file","$basedir$configpath");
				# now the other path (/usr/share/$package or similar)
				mycopy("$Master/$file","$basedir$secondpath");
				# return the config path
				$returnvalue = $configpath;
			} elsif ($act eq "link") {
				# make the defaultdestname a LINK to the supplieddestname,
				# but do NOT create the supplieddestname
				$opt_debug && print STDERR "link\n";
				&mkpath(dirname("$basedir$defaultpathcomponent/$defaultdestname"));
				unless ($opt_onlyscripts == 1) {
					symlink("$supplieddestname", "$basedir$defaultpathcomponent/$defaultdestname") or
					die "Cannot symlink $basedir$defaultpathcomponent/$defaultdestname -> $supplieddestname: $!\n"
				};
				$returnvalue = $supplieddestname;
			} elsif (($act eq "move-link") || ($act eq "config-move-link")) {
				$opt_debug && print STDERR "move-link\n";
				# move the file to the new location, and create a link
				# from the defaultdestname -> supplieddestname
				&mkpath(dirname("$basedir$supplieddestname"));
				mycopy("$Master/$file","$basedir$supplieddestname");
				&mkpath(dirname("$basedir$defaultpathcomponent/$defaultdestname"));
				unless ($opt_onlyscripts == 1) {
					symlink($supplieddestname, "$basedir$defaultpathcomponent/$defaultdestname") or
						die "Cannot symlink $basedir$defaultpathcomponent/$defaultdestname -> $supplieddestname: $!\n"
				};
				$returnvalue = $supplieddestname; ## ?? or $defaultdestname????
			} elsif ($act eq "add-link") {
				$opt_debug && print STDERR "add-link\n";
				# install the file in its default location, but add a
				# symlink $supplieddestname -> $defaultdestname
				mycopy("$Master/$file","$basedir$defaultpathcomponent/$defaultdestname");
				&mkpath(dirname("$basedir$supplieddestname"));
				unless ($opt_onlyscripts == 1) {
					symlink("$defaultpathcomponent/$defaultdestname","$basedir$supplieddestname") or
						die "Cannot symlink, $basedir$supplieddestname -> $defaultpathcomponent/$defaultdestname: $!\n"
				};
				$returnvalue = "$defaultpathcomponent/$defaultdestname";
			} elsif ($act eq "replace-link") {
				$opt_debug && print STDERR "replace-link\n";
				# $supplieddestname must be of the form aaa%bbb 
				# make aaa -> bbb and do nothing else
				my ($a,$b) = split(/%/,$supplieddestname);
				my $aa = absolute_path($a);
				&mkpath(dirname("$basedir$aa"));
				unless ($opt_onlyscripts == 1) {
					symlink($b,"$basedir$aa") or die "Cannot symlink $basedir$aa -> $b: $!\n"
				};
				$returnvalue = $b;
			} elsif ($act eq "") {
				$opt_debug && print STDERR ":empty:\n";
				$returnvalue = "";
				# do nothing, the file is killed
			} else {
				print STDERR "maplines=$maplines\nact = $TeXLive{'all'}{'file_map_actions'}{$pat}\n";
				print STDERR "Unknown action $act in config file, terminating!\n";
				exit 1;
			}
			last MAPPINGS;
		}
	}
	if ($gotremapped == 0) {
		if ($finalremap ne "" && $defaultdestname =~ m|$finalremap|) {
			my $foo="\$finaldest = \"$finaldest\"";
			eval $foo;
			$opt_debug && print STDERR "finalremap COPY: $finaldest\n";
			&mkpath(dirname("$basedir$finaldest"));
			mycopy("$Master/$file","$basedir$finaldest");
			$returnvalue = $finaldest;
		} else {
			$opt_debug && print STDERR "NORMAL COPY: $basedir$defaultpathcomponent/$defaultdestname\n";
			my $finaldest = "$basedir$defaultpathcomponent/$defaultdestname";
			&mkpath(dirname($finaldest));
			mycopy("$Master/$file", $finaldest);
			#
			# if a file name matches a linked script, also create the
			# actual link
			if (defined($TeXLive{'all'}{'linkedscript'}{$file})) {
				unless ($opt_onlyscripts == 1) {
					&mkpath($bindest);
					my @foo = split ",", $TeXLive{'all'}{'linkedscript'}{$file};
					for my $i (@foo) {
						symlink("../share/texlive/$file", "$bindest/$i") or
							die "Cannot symlink $bindest/$i -> ../share/texlive/$file: $!\n"
					}
				};
			}
			$returnvalue = "$defaultpathcomponent/$defaultdestname";
		}
	}
	return($returnvalue);
}

### Local Variables:
### perl-indent-level: 4
### tab-width: 4
### indent-tabs-mode: t
### End:
# vim:set tabstop=4 autoindent: #
