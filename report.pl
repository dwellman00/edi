#!/usr/bin/perl
#
# *** MANAGED BY PUPPET - DO NOT EDIT DIRECTLY! ***
#
#
# 05/2009 Dale Wellman
#
# Parse the archived EDI files and generate a summation of activity
#

use Getopt::Std;

%options = ();
@timeData = ();
getopts('vd:') or USAGE();

if( $opt_v )
{
        $DEBUG = 1;
}

#
# If -d option is given then a time stamp is on the command line.  This
# is a cludgy way to make sure date variables are set for later use in the
# script.
#
if( $opt_d )
{
	@temp = split(//, $opt_d);
	$year = $temp[0] . $temp[1];
	$month = $temp[2] . $temp[3];
	$mday = $temp[4] . $temp[5];
	$DATESTAMP = $year . $month . $mday;
	$wday = 2;		# just set wday to anything other than 0,6
} 
else 
{
	@timeData = localtime(time);
	$wday = $timeData[6];
	$mday = sprintf("%02d", $timeData[3]);
	$month = sprintf("%02d", $timeData[4] + 1);
	$year = sprintf("%02d", $timeData[5] % 100);
	$DATESTAMP = $year . $month . $mday;
}

# Setup array for readable output
@months = ( "January", "February", "March", "April",
                   "May", "June", "July", "August", "September",
                   "October", "November", "December" );


##
## Important system variables
##
$OUTDIR         = "/path/outbound/archive";
$INDIR          = "/path/inbound";

#
# List of incoming files to parse
#
# if a date stamp is given on the command line, we need to
# parse an archived file.txt file.
#
if( $opt_d )
{
	@InFileList = ( "archive/file.txt.$DATESTAMP" );
}
else
{
	@InFileList = ( "file.txt" );
}

#
# List of outgoing files to parse
#
@OutFileList = ( "DSNO.$DATESTAMP.ARC", "INO.$DATESTAMP.ARC", 
	"ECE_POAO.$DATESTAMP.ARC" );

#
# First value is used later to pattern match on which output file
# we are currently looping through.  The second value is then used
# for readable output.
#
%FileList = ( 	"DSNO", "Advanced Shipment Notices",
		"INO", "Invoices",
		"ECE_POAO", "Purchase Order Acknowledgements"
		);

for $file ( @InFileList )
{
	DEBUG( "Opening $INDIR/$file\n" );
	open( INPUT_FILE, "<$INDIR/$file" ) or
		ERROR( "Error opening file $INDIR/$file: $!\n" );
	while ( <INPUT_FILE> ) 
	{
#		print $_;
		@line = split;
		$Sent{$line[1]} = "$line[0]";
	}
	print "========================================\n";
	print "Incoming EDI Orders - ", $months[$month-1], " $mday, 20", $year, "\n";
	print "========================================\n";
	print "\n";

	foreach $ID (sort keys %Sent)
	{
		next if $wday == 0 || $wday == 6;
		print "Vendor: $Sent{$ID}, ID: $ID\n";
	}
}

%Sent = '';

for $file ( @OutFileList )
{
	%Sent = '';
	DEBUG( "Opening $OUTDIR/$file\n" );
	open( INPUT_FILE, "<$OUTDIR/$file" );
	while ( <INPUT_FILE> ) 
	{
		@line = split;
		$Sent{$line[1]} = "$line[0]";
	}
	@test = split(/\./, $file);
	$t = $test[0];
	print "\n=======================================================\n";
	print "Outgoing ", $FileList{$t}, " - ", $months[$month-1], " $mday, 20", $year, "\n";
	print "=======================================================\n";
	print "\n";

	foreach $ID (sort keys %Sent)
	{
		next if ( $ID eq '' );
		print "Vendor: $Sent{$ID}, ID: $ID\n";
	}
}



sub DEBUG
{
        print STDERR "DEBUG: " . "@_" if $DEBUG;
}

sub ERROR
{
        print STDERR @_;
}

sub USAGE
{
	print STDERR << "EOF";
Usage: $0 [-v verbose] [-d date]
EOF
	exit;
}
