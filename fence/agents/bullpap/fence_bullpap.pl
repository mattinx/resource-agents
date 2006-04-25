#!/usr/bin/perl

###############################################################################
###############################################################################
##
##  Copyright (C) Sistina Software, Inc.  1997-2003  All rights reserved.
##  Copyright (C) 2004 Red Hat, Inc.  All rights reserved.
##  
##  This copyrighted material is made available to anyone wishing to use,
##  modify, copy, or redistribute it subject to the terms and conditions
##  of the GNU General Public License v.2.
##
###############################################################################
###############################################################################
use Getopt::Std;
use POSIX;

# Get the program name from $0 and strip directory names
$_=$0;
s/.*\///;
my $pname = $_;

$action = "reboot"; # Default fence action
my $bulldir = "/usr/local/bull/NSMasterHW/bin";

stat($bulldir);
die "NSMasterHW not installed correctly" if ! -d _;

# WARNING!! Do not add code bewteen "#BEGIN_VERSION_GENERATION" and 
# "#END_VERSION_GENERATION"  It is generated by the Makefile

#BEGIN_VERSION_GENERATION
$FENCE_RELEASE_NAME="";
$SISTINA_COPYRIGHT="";
$BUILD_DATE="";
#END_VERSION_GENERATION


sub usage
{
	print "Usage:\n";
	print "\n";
	print "$pname [options]\n";
	print "\n";
	print "Options:\n";
	print "  -a <ip>          IP address or hostname of PAP console\n";
	print "  -h               usage\n";
	print "  -l <name>        Login name\n";
	print "  -d <domain>      Domain to operate on\n";
	print "  -o <string>      Action:  on, off, reboot (default) or status\n";
	print "  -p <string>      Password for login\n";
	print "  -q               quiet mode\n";
	print "  -V               version\n";
	print "\n";
	print "When run with no arguments, $pname takes arguments from ";
	print "standard\ninput, one line per option.  They are as follows:\n";
	print "\n";
	print "  ipaddr=<ip>      Same as -a command line option\n";
	print "  login=<name>     Same as -l command line option\n";
	print "  domain=<domain>  Same as -d command line option\n";
	print "  option=<string>  Same as -o command line option\n";
	print "  passwd=<string>  Same as -p command line option\n\n";

	exit 0;
}

sub fail
{
	($msg) = @_;
	print $msg."\n" unless defined $quiet;
	exit 1;
}

sub fail_usage
{
	($msg)=@_;
	print STDERR $msg."\n" if $msg;
	print STDERR "Please use '-h' for usage.\n";
	exit 1;
}

sub version
{
	print "$pname $FENCE_RELEASE_NAME $BUILD_DATE\n";
	print "$SISTINA_COPYRIGHT\n" if ( $SISTINA_COPYRIGHT );

	exit 0;
}

sub get_options_stdin
{
	my $opt;
	my $line = 0;
	while( defined($in = <>) )
	{
		$_ = $in;
		chomp;

		# strip leading and trailing whitespace
		s/^\s*//;
		s/\s*$//;
	
		# skip comments
		next if /^#/;

		$line+=1;
		$opt=$_;
		next unless $opt;

		($name,$val)=split /\s*=\s*/, $opt;

		if ( $name eq "" )
		{  
			print STDERR "parse error: illegal name in option $line\n";
			exit 2;
		}
	
		# DO NOTHING -- this field is used by fenced
		elsif ($name eq "agent" ) { } 

		elsif ($name eq "ipaddr" ) 
		{
			$host = $val;
		} 
		elsif ($name eq "login" ) 
		{
			$login = $val;
		} 
		elsif ($name eq "option" )
		{
			$action = $val;
		}
		elsif ($name eq "passwd" ) 
		{
			$passwd = $val;
		} 
		elsif ($name eq "password" ) 
		{
			$passwd = $val;
		} 
		elsif ($name eq "domain" ) 
		{
			$domain = $val;
		} 
		elsif ($name eq "debuglog" ) 
		{
			$verbose = $val;
		} 
		else 
		{
			fail "parse error: unknown option \"$opt\"";
		}
	}
}

sub get_power_state
{
	my ($ip,$dom,$user,$pass,$junk) = @_;
	fail "missing IP address in get_power_state()" unless defined $ip;
	fail "missing domain to get_power_state()" unless defined $dom;
	fail "illegal argument to get_power_state()" if defined $junk;

	my $state="";
	my $cmd = $bulldir . "/pampower.pl";
	
	$cmd = $cmd . " -a status";
	$cmd = $cmd . " -M $ip -D $dom";
	if (defined $user) {
		$cmd = $cmd . "	-u $user";
	}
	if (defined $pass) {
		$cmd = $cmd . " -p $pass";
	}

	$state=system($cmd);
	WIFEXITED($state) || die "child killed abnormally";

	$state=WEXITSTATUS($state);
	if ($state == 0) {
		$state = "ON";
	} elsif ($state == 1) {
		$state = "OFF";
	} else {
		$state = "$state TRANSITION";
	}

	$_=$state;
}

sub set_power_state
{
	my ($ip,$dom,$set,$user,$pass,$junk) = @_;
	fail "missing action to set_power_state()" unless defined $set;
	fail "missing IP address in set_power_state()" unless defined $ip;
	fail "missing domain to set_power_state()" unless defined $dom;
	fail "illegal argument to set_power_state()" if defined $junk;

	my $state="";
	my $cmd = $bulldir . "/pampower.pl";
	
	if ($set =~ /on/) {
		$cmd = $cmd . " -a on";
	} else {
		$cmd = $cmd . " -a off_force";
	}
	
	$cmd = $cmd . " -M $ip -D $dom";
	if (defined $user) {
		$cmd = $cmd . "	-u $user";
	}
	if (defined $pass) {
		$cmd = $cmd . " -p $pass";
	}

	$state=system "$cmd";

	$_=$state;
}

# MAIN

if (@ARGV > 0) 
{
	getopts("a:hl:d:o:p:qv:V") || fail_usage ;

	usage if defined $opt_h;
	version if defined $opt_V;

	$host     = $opt_a if defined $opt_a;
	$login    = $opt_l if defined $opt_l;
	$passwd   = $opt_p if defined $opt_p;
	$action   = $opt_o if defined $opt_o;
	$domain	  = $opt_d if defined $opt_d;
	$verbose  = $opt_v if defined $opt_v;
	$quiet    = $opt_q if defined $opt_q;

	fail_usage "Unknown parameter." if (@ARGV > 0);

	fail_usage "No '-a' flag specified." unless defined $host;
	fail_usage "No '-d' flag specified." unless defined $domain;
	fail_usage "No '-l' flag specified." unless defined $login;
	fail_usage "No '-p' flag specified." unless defined $passwd;
	fail_usage "Unrecognised action '$action' for '-o' flag"
		unless $action =~ /^(on|off|reboot|status)$/i;
} 
else 
{
	get_options_stdin();

	fail "failed: no IP address" unless defined $host;
	fail "failed: no domain" unless defined $domain;
	fail "failed: no login name" unless defined $login;
	fail "failed: no password" unless defined $passwd;
	fail "failed: unrecognized action: $action"
		unless $action =~ /^(on|off|reboot|status)$/i;
}

# convert $action to lower case 
$_=$action;
if    (/^on$/i)     { $action = "on"; }
elsif (/^off$/i)    { $action = "off"; }
elsif (/^reboot$/i) { $action = "reboot"; }
elsif (/^status$/i) { $action = "status"; }

#
# If if pampower / pamreset don't exist, we're done.
#
# -M -- the maintenance port on the NovaScale Windows 2000 master server
# -D -- the Domain to reboot
# -u -- User name
# -p -- Password
#
#/usr/local/bull/NSMasterHW/bin/pamreset.pl 
#    -M 192.168.78.169 -D Domaine2-8CPU -u Administrator -p administrator
#
#/usr/local/bull/NSMasterHW/bin/pampower.pl -a off_force 
#    -M 192.168.78.169 -D Domaine2-8CPU -u Administrator -p administrator
#
#/usr/local/bull/NSMasterHW/bin/pampower.pl -a on 
#    -M 192.168.78.169 -D Domaine2-8CPU -u Administrator -p administrator
#
# Do the command
#
$success=0;
$_ = $action;
if (/(on|off)/)
{
	my $timeout = 120; # 120 = max of (60, 120).  Max timeout for "on"
			   # on 32-way bull machines

	set_power_state $host,$domain,$action,$login,$passwd;
	do {
		sleep 5;
		$state=get_power_state $host,$domain,$login,$passwd;
		$timeout -= 5;
	} while ($timeout > 0 && !($state =~ /^$action$/i));

	$success = 1 if ($state=~/^$action$/i);
}
elsif (/reboot/)
{
	my $timeout = 60; # 60 seconds for "off" for 32-way bull machines

	set_power_state $host,$domain,"off",$login,$passwd;
	do {
		sleep 5;
		$state=get_power_state $host,$domain,$login,$passwd;
		$timeout -= 5;
	} while ($timeout > 0 && $state != 0);

	if ($timeout <= 0) {
		$success = 0;
	} else  {
		$timeout = 120; # 120 seconds for on, for 32-way bull machines
		set_power_state $host,$domain,"on",$login,$passwd;
		do {
			sleep 5;
			$state=get_power_state $host,$domain,$login,$passwd;
			$timeout -= 5;
		} while ($timeout > 0 && $state != 0);

		$success = 1 if ($state == 0);
	}
}
elsif (/status/)
{
	get_power_state $host,$domain,$login,$passwd;
	$state=$_;
	$success = 1 if defined $state;
}
else
{
	fail "fail: illegal action";
}

if ($success)
{
	print "success: domain $domain $action". ((defined $state) ? ": $state":"")
		."\n" unless defined $quiet;
	exit 0;
}
else
{
	fail "fail: domain $domain $action";	
	exit 1
}


