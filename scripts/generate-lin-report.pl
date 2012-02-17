#!/usr/bin/perl
#

my %Warnings;
my %Errors;

sub do_log_file {
	my ($fname) = @_;
	my ($type,$pkg,$tag,$rest);
	open FOO,"<$fname" or die "Cannot open $fname: $!\n";
	my @lines = <FOO>;
	close FOO;
	foreach $l (@lines) {
		chomp $l;
		($type, $pkg, $rest) = split /: /, $l;
		($tag,@inf) = split / /, $rest;
		if ($type eq 'E') {
			local %foo = %{$Errors{$tag}};
			local @bar = @{$foo{$pkg}};
			if ($#inf >= 0) {
				push @bar, join(" ",@inf);
			}
			$foo{$pkg} = \@bar;
			$Errors{$tag} = \%foo;
		}
		if ($type eq 'W') {
			local %foo = %{$Warnings{$tag}};
			local @bar = @{$foo{$pkg}};
			if ($#inf >= 0) {
				push @bar, join(" ",@inf);
			}
			$foo{$pkg} = \@bar;
			$Warnings{$tag} = \%foo;
		}
	}
}

foreach $f (@ARGV) {
	do_log_file($f);
}

print "\n\nERRORS:\n";
foreach $k (keys %Errors) {
	print "$k:\n";
	%foo = %{$Errors{$k}};
	foreach $pkg (keys %foo) {
		@bar = @{$foo{$pkg}};
		print "\t$pkg:\n";
		foreach $l (@bar) {
			print "\t\t$l\n";
		}
	}
	print "\n";
}

print "WARNINGS:\n";
foreach $k (keys %Warnings) {
	print "$k:\n";
	%foo = %{$Warnings{$k}};
	foreach $pkg (keys %foo) {
		@bar = @{$foo{$pkg}};
		print "\t$pkg:\n";
		foreach $l (@bar) {
			print "\t\t$l\n";
		}
	}
	print "\n";
}
