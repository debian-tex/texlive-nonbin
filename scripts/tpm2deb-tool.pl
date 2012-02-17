#!/usr/bin/perl
#
# tpm2deb-tool.pl
# machinery to create debian packages from TeX Live depot
# (c) 2005, 2006 Norbert Preining
#
# $Id: tpm2deb.pl 2080 2006-12-15 12:03:49Z preining $
#
# configuration is done via the file tpm2deb.cfg
#

#use strict;
#no strict 'refs';

my ($mydir, $mmydir);
BEGIN {   # get our other local perl modules.
	($mydir = $0) =~ s,/[^/]*$,,;
	if ($mydir eq $0) { $mydir = `pwd` ; chomp($mydir); }
	if (!($mydir =~ m,/.*,,)) { $mmydir = `pwd`; chomp($mmydir); $mydir = "$mmydir/$mydir" ; }
	unshift (@INC, $mydir);
	unshift (@INC, "./all/debian");
	unshift (@INC, "/src/TeX/texlive-svn/Build/tools/");
}

#use Strict;
use Getopt::Long;
use File::Basename;
use File::Copy;
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use Storable;
## not needed, atm we are calling eperl binary use Parse::ePerl;
#use XML::DOM;
use Cwd;
#use FileUtils qw(canon_dir cleandir make_link newpath member
#		 normalize substitute_var_val dirname diff_list remove_list
#		 rec_rmdir sync_dir walk_dir start_redirection stop_redirection);
#use Tpm;


# pre set $opt_master to ./LocalTPM which contains also the Tools dir
my $opt_master = "./LocalTPM";
our $opt_debug=0;
my $globalreclevel=1;

my $result = GetOptions ("debug!", 	# debug mode
	"master=s" => \$opt_master	# location of Master
	);
 
our $Master;

if (!($opt_master =~ m,/.*$,,)) {
	$Master = `pwd`;
	chomp($Master);
	$Master .= "/$opt_master";
} else {
	$Master = $opt_master;
}
my $TpmGlobalPath = $Master;
my $DataGlobalPath = $Master;

#
# put Master/Tools/ into the include path to find TeX Live perl modules
#
unshift (@INC, "$Master/../Build/tools");
#
# these we can only load now that we have correctly set the path to Master
#
#require Strict;
#require XML::DOM;
#require FileUtils;
#import FileUtils qw(canon_dir cleandir make_link newpath member
#	normalize substitute_var_val dirname diff_list remove_list
#	rec_rmdir sync_dir walk_dir start_redirection stop_redirection);
#require Tpm;

#my $parser = new XML::DOM::Parser;
#my $startdir=getcwd();
#chdir($startdir);
File::Basename::fileparse_set_fstype('unix');

use tpm2debcommon ;

&main(@ARGV);

1;


####################################################################
#
# PART 0: The main() function
#
####################################################################

sub main {
	local ($cmd,@packages) = @_;
	${Tpm::MasterDir} = $TpmGlobalPath;
	$arch = "all";
	$Tpm::CurrentArch = "i386-linux";
	if ("$cmd" eq "store-tpm") {
		load_collection_tpm_data();
		store_tpm("tpm.data.new");
		exit 0;
	}
	initialize_config_file_data();
	if (-r "tpm.data") {
		print "loading tpm data from dump ...\n";
		$tpmdataref = retrieve("tpm.data");
		%TpmData = %{$tpmdataref};
		print " ... done\n";
	} else {
		load_collection_tpm_data();
	}
	build_data_hash();
	check_consistency();
	if ("$cmd" eq "dump") {
		dump_texlive_data(0);
		print "Done\n";
		exit 0;
	} elsif ("$cmd" eq "fulldump") {
		dump_texlive_data(1);
		print "Done\n";
		exit 0;
	} elsif ("$cmd" eq "file-and-tpm") {
		file_and_tpm();
		exit 0;
	} elsif ("$cmd" eq "dumptpm") {
		dump_tpm_data();
		print "Done\n";
		exit 0;
	} elsif ("$cmd" eq "store-tpm") {
		store_tpm("tpm.data.new");
	} elsif ("$cmd" eq "check") {
		print "Done\n";
		exit 0;
	}
	foreach $package (@packages) {
		# 
		# various variables have to be set
		#
		$arch = get_arch($package);
		print "Working on $package, arch=$arch\n";
		if ("$cmd" eq "get-packages") {
			get_internal_deps($package,0);
		} elsif ("$cmd" eq "included-packages") {
			@foo = @{$TeXLive{$package}{'includedpackages'}};
			print "$package contains: @foo\n";
		} elsif ("$cmd" eq "list-doc-dirs") {
			list_doc_dirs($package);
		} elsif ("$cmd" eq "get-files") {
			my %h = %{&get_all_files($package,$globalreclevel)};
			foreach my $f (@{$h{RunFiles}}) {
				print "RunFile-> $f\n";
			}
			foreach my $f (@{$h{BinFiles}}) {
				print "BinFile-> $f\n";
			}
			foreach my $f (@{$h{DocFiles}}) {
				print "DocFile-> $f\n";
			}
			foreach my $f (@{$h{SourceFiles}}) {
				print "SourceFile-> $f\n";
			}
			foreach my $f (@{$h{RemoteFiles}}) {
				print "RemoteFile-> $f\n";
			}
		} else {
			print "cmd >$cmd< undefined!\n";
		}
	}
}


sub store_tpm {
	local ($fn) = @_;
	print "Storing TpmData into $fn ...\n";
	store \%TpmData, $fn;
	print "  ...done\n";
}


sub file_and_tpm {
	foreach $t ('TLCore', 'Documentation', 'Package') {
		my %foo = %{$TpmData{$t}};
		foreach $p (keys %foo) {
			my $bar;
			my $bar = [ @{$TpmData{$t}{$p}{'BinFiles'}} , 
						@{$TpmData{$t}{$p}{'RunFiles'}} ,
						@{$TpmData{$t}{$p}{'DocFiles'}} ,
						@{$TpmData{$t}{$p}{'SourceFiles'}} ,
						@{$TpmData{$t}{$p}{'RemoteFiles'}} ];
			foreach (@$bar) {
				print "$_;$p;$TpmData{$t}{$p}{'License'}\n";
			}
		}
	}
}

sub dump_tpm_data {
	print "Dumping TpmData\n\n";
	foreach $t ('TLCore', 'Documentation', 'Package') {
		print "Dumping $t:\n";
		my %foo = %{$TpmData{$t}};
		foreach $p (keys %foo) {
			print "$p:\n";
			print "\tbinfiles: @{$TpmData{$t}{$p}{'BinFiles'}}<<<\n";
			print "\trunfiles: @{$TpmData{$t}{$p}{'RunFiles'}}<<<\n";
			print "\tdocfiles: @{$TpmData{$t}{$p}{'DocFiles'}}<<<\n";
			print "\tsourcefiles: @{$TpmData{$t}{$p}{'SourceFiles'}}<<<\n";
			print "\tremotefiles: @{$TpmData{$t}{$p}{'RemoteFiles'}}<<<\n";
			print "\ttitle: $TpmData{$t}{$p}{'Title'}\n";
			print "\tDescription: $TpmData{$t}{$p}{'Description'}\n";
			print "\tLicense: $TpmData{$t}{$p}{'License'}\n";
			print "\tInstallation: @{$TpmData{$t}{$p}{'Installation'}}\n";
			print "\tDep-Package: @{$TpmData{$t}{$p}{'Package'}}\n";
			print "\tDep-TLCore: @{$TpmData{$t}{$p}{'TLCore'}}\n";
		}
	}
}


	
sub dump_texlive_data {
	my ($full) = @_;
	print "Dumping ", $full?"full ":"", "TeXLive data:\n\n",$full?"Collections:\n":"";
	foreach $p (sort keys %TeXLive) {
		if (!$full && ($TeXLive{$p}{'type'} ne "TLCore")) { next ; }
		my @ex=get_all_executes($p,$globalreclevel);
		print "$p\n";
		print "\ttype: $TeXLive{$p}{'type'}<<<\n";
		print "\ttitle: $TeXLive{$p}{'title'}<<<\n";
		print "\tdescr: $TeXLive{$p}{'description'}<<<\n";
		print "\tlicense: $TeXLive{$p}{'license'}<<<\n";
		print "\tpackages: @{$TeXLive{$p}{'includedpackages'}}<<<\n";
		print "\tsuggests: @{$TeXLive{$p}{'suggests'}}<<<\n";
		print "\tconflict: @{$TeXLive{$p}{'conflicts'}}<<<\n";
		print "\tdepends:  @{$TeXLive{$p}{'depends'}}<<<\n";
		print "\texecutes: @{$TeXLive{$p}{'executes'}}<<<\n";
		print "\trec-exe:  @ex<<<\n";
		print "\trunfiles: @{$TeXLive{$p}{'runfiles'}}<<<\n";
		print "\tdocfiles: @{$TeXLive{$p}{'docfiles'}}<<<\n";
		print "\tbinfiles: @{$TeXLive{$p}{'binfiles'}}<<<\n";
		print "\tsourcefiles: @{$TeXLive{$p}{'sourcefiles'}}<<<\n";
		print "\tremotefiles: @{$TeXLive{$p}{'remotefiles'}}<<<\n";
	}
}

sub list_doc_dirs {
	local ($key, $entry) = @_;
	my %lists = %{&get_all_files($entry,$globalreclevel)};
	@allfiles = @{$lists{'DocFiles'}};
	foreach $f (@allfiles) {
		print dirname($f), " $f", "\n";
	}
}


sub get_internal_deps {
	local ($key,$tpmname) = @_;
	my $tpm = $TpmData{$key}{$tpmname}{tpm};
	my %requires = $tpm->getHash("Requires");
	my @debreqlist = ();
	my @packagereqlist = ();
	foreach my $k (keys %requires) {
		foreach my $e (@{$requires{$k}}) {
			if ($k eq "TLCore") {
				push @debreqlist, "$e";
			} else {
				push @reqlist, "$k/$e";
			}
		}
	}
	print $tpm->getAttribute("Name") . " requires @reqlist \n";
}


# vim:set tabstop=4: #
