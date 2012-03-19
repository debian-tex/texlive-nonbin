#!/usr/bin/perl

BEGIN {
  $^W = 1;
  chomp ($mydir = `dirname $0`);
  unshift (@INC, "/usr/share/texlive/tlpkg");
}

$^W = 1;
use strict;
use Cwd qw/abs_path/;
use Pod::Usage;
use Getopt::Long qw(:config no_autoabbrev permute);
use TeXLive::TLPaper;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");


&main();

sub main {
  # the script always runs in sys mode
  chomp(my $texmfsysconfig = `kpsewhich -var-value=TEXMFSYSCONFIG`);
  chomp(my $texmfsysvar = `kpsewhich -var-value=TEXMFSYSVAR`);
  $ENV{"TEXMFCONFIG"} = $texmfsysconfig;
  $ENV{"TEXMFVAR"} = $texmfsysvar;

  my $action = shift @ARGV;
  if ($action =~ m/^status$/i) {  # "tl-paper status" shows the current settings
    TeXLive::TLPaper::paper_all($texmfsysconfig,undef);
    
  } elsif ($action =~ m/^list$/i) { # "tl-paper list prg" lists options for prg
    my $prg = shift @ARGV;
    if (!$prg) {
      usage();
      exit 1;
    }
    # the following actually also *reads* the configuration and returns
    # a list where the first item is the one selected.
    my ($current_paper, @other_options) = TeXLive::TLPaper::get_paper_list($prg);
    for my $i ($current_paper, sort @other_options) {
      print "$i\n";
    }
    # for simply getting the list of supported paper sizes without reading
    # anything, one can use:
    # my @paper_options = keys(%{${prg}_papersize});

  } elsif ($action =~ m/^set$/i) { # "tl-paper set <prg|all> <paper>" sets paper
    my $prg = shift @ARGV;
    my $newpaper = shift @ARGV;

    if ($prg !~ m/^(xdvi|pdftex|dvips|dvipdfmx|dvipdfm|context|all)$/i) {
      usage();
      exit 1;
    }
    if ($prg =~ m/^all$/i) {
      if ($newpaper !~ /^(a4|letter)$/) {
        # we cannot deal with that for now, only a4|letter supported for
        # all programs
        usage();
        exit 1;
      }
      TeXLive::TLPaper::paper_all($texmfsysconfig,$newpaper);
    
    } else {
      TeXLive::TLPaper::do_paper($prg,$texmfsysconfig,$newpaper);
    }
  
    #
    # we probably have changed the paper, so run the execute actions
    # as announced by TLPaper, that is $::files_changed and 
    # $::regenerate_all_formats.
    #
    # I would *LIKE* to call the shell code generated by
    # dh_installtex, i.e., the postinst-tex shell code
    # here ... why is that not possible???
    if ($::files_changed) {
      `mktexlsr /var/lib/texmf`;
      #
      # the following is propably a better approach ;-)
      #if (system("kpsewhich --version >/dev/null 2>&1") == 0) {
      #  if (system("which mktexlsr >/dev/null") == 0) {
      #    
      #  }
      #}
    }
    if ($::regenerate_all_formats) {
      `fmtutil-sys --refresh`;
    }

  } elsif ($action =~ m/^get$/i) { # "tl-paper get prg" gets paper setting for prg
    my $prg = shift @ARGV;
    if ($prg !~ m/^(xdvi|pdftex|dvips|dvipdfmx|dvipdfm|context)$/i) {
      usage();
      exit 1;
    }
    my ($current_paper, @other_options) = TeXLive::TLPaper::get_paper_list($prg);
    print "$current_paper\n";
    
  } else {
    usage();
    exit 1;
  }
  exit 0;
}

sub usage {
  print STDERR "
tl-paper: inquire and set paper settings for various programs in the TeX World.


usage:
  tl-paper list <program>     lists available papers, current paper first
  tl-paper status             lists all current settings
  tl-paper get <program>      prints the current paper for <program>
  tl-paper set <program> <newpaper>    sets new paper for <program>
  tl-paper set all <a4|letter>         sets new paper for all programs

";
}



### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #