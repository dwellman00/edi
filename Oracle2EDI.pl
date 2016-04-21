#!/usr/bin/perl
#
# *** MANAGED BY PUPPET - DO NOT EDIT DIRECTLY! ***
#
#
# 04/2007 Dale Wellman
#
# Script to open a FTP connection with Company, outsourced EDI provider
#
#

# Use internal perl FTP libraries
use Net::FTP;
use Getopt::Std;
use File::Copy;


###
### -v for verbose
### -u for uploading files
### -d for downloading files
###
getopts('vdu');

if( ! $opt_d && ! $opt_u )
{
	USAGE();
}

if( $opt_v )
{
	$DEBUG = 1;
}

## 
## time routines to create timestamp for use in archival process
##
@timeData = localtime(time);
$mday = sprintf("%02d", $timeData[3]);
$month = sprintf("%02d", $timeData[4] + 1);
$year = sprintf("%02d", $timeData[5] % 100);
$DATESTAMP = $year . $month . $mday;


$hour = sprintf("%02d", $timeData[2]);
$min = sprintf("%02d", $timeData[1]);
$sec = sprintf("%02d", $timeData[0]);
$TIMESTAMP = "$hour:$min:$sec";

##
## Important system variables
##
$OUTDIR		= "/path/outbound";
$INDIR		= "/path/inbound";
$LOGDIR		= "/path/log";
$ARCHIVE	= "archive";
$REMOTE		= "ftp.company.net";
$REMOTELOGIN	= "someuser";
$REMOTEPASS	= "<changeme123>";
$REMOTEDIR	= "/path/extract";
$REMOTEPUT	= "/path/collecttemp";
$REMOTEFILE	= "file.txt";

open( LOG, ">>$LOGDIR/EDI.$DATESTAMP.log" );

print LOG<<EOF;
=========================================
BEGIN LOG : $TIMESTAMP
=========================================
EOF


if( $opt_u )
{
	opendir( DIR, $OUTDIR );
##
## step through list of files in OUTDIR for any:
##
##	DSNO*
##	INO*
##	ECE_POAO*
##
	DEBUG( "Searching $OUTDIR for files to upload\n" );
	while( my $file = readdir( DIR ) )
	{
		DEBUG( "Testing file: $file\n" );
		if( $file =~ /^DSNO*/ )
		{
##
##  Make sure the file is not zero length
##
			if( -z "$OUTDIR/$file" )
			{
				DEBUG( "DSNO file is zero length: $file\n");
				CLEANUP( $file );
			} else {
				DEBUG( "Adding $file to DSNO array\n" );
				push( @DSNO, $file );
			}
		}
		if( $file =~ /^INO*/ )
		{
##
## Quick fix for how the invoice file is generating in Oracle.  Currently,
## the file name is hardcoded in the scheduled concurrent job.  If there
## are errors in the file over multiple days, it becomes impossible to track
## the original file and date of invoice request.
##
			if( $file =~ /^INO2555.dat$/ )
			{
				DEBUG( "Fixing INO file name...\n" );
				open INPUT_FILE, "< $OUTDIR/$file" or
					EXIT("ERROR: can't open: $OUTDIR/$file\n");
				open OUTPUT_FILE, ">> $OUTDIR/INO$DATESTAMP.dat" or
					EXIT("ERROR: can't open: $OUTDIR/INO$DATESTAMP.dat\n");

				while ( defined ( my $line = <INPUT_FILE> ) ) 
				{
					print OUTPUT_FILE $line;
				}
	
				close INPUT_FILE;
				close OUTPUT_FILE;
				DEBUG( "Deleting original INO file INO2555.dat...\n" );
				unlink( "$OUTDIR/INO2555.dat" );
				$file = "INO$DATESTAMP.dat";
				DEBUG( "Adding $file to INO array\n" );
				push( @INO, $file );
			} else {
##
##  Make sure the file is not zero length
##
				if( -z "$OUTDIR/$file" )
				{
					DEBUG( "INO file is zero length: $file\n");
					CLEANUP( $file );
				} else {
					DEBUG( "Adding $file to INO array\n" );
					push( @INO, $file );
				}
			}
		}
		if( $file =~ /^ECE_POAO*/ )
		{
			if( -z "$OUTDIR/$file" )
			{
				DEBUG( "POAO file is zero length: $file\n");
				CLEANUP( $file );
			} else {
				DEBUG( "Adding $file to POAO array\n" );
				push( @ECE_POAO, $file );
			}
		}
	}
	close( DIR );

}

DEBUG( "using the following info for FTP:\n
		Remote Host:	$REMOTE
		Username: 	$REMOTELOGIN
		Password: 	$REMOTEPASS
		GET Directory:	$REMOTEDIR
		PUT Directory :	$REMOTEPUT\n\n" );

###
### Open FTP connection
###
DEBUG( "connecting to $REMOTE...\n" ); 
$ftp = Net::FTP->new($REMOTE,Timeout=>240) or 
	EXIT( "Can not open FTP to: $REMOTE: $!\n" );
	
###
### Login
###
DEBUG( "logging in...\n" ); 
$ftp->login($REMOTELOGIN,$REMOTEPASS) or
	EXIT( "Can not login to: $REMOTE: Username: $REMOTELOGIN: $!\n" );
	
if( $opt_d )
{
##
## Archive last order file
##
	if( -s "$INDIR/$REMOTEFILE" )
	{
##
## If there is already an archived file, append the recent file onto the
## archived version.  This keeps time stamps on a per day basis.
##

		if( -s "$INDIR/$ARCHIVE/$REMOTEFILE.$DATESTAMP" )
		{
			DEBUG( "Archive file exists, appending...\n") ;
			open INPUT_FILE, "< $INDIR/$REMOTEFILE" or
				EXIT("ERROR: can't open: $INDIR/$REMOTEFILE\n");
			open OUTPUT_FILE, ">> $INDIR/$ARCHIVE/$REMOTEFILE.$DATESTAMP" or
				EXIT("ERROR: can't open: $INDIR/$REMOTEFILE\n");

			while ( defined ( my $line = <INPUT_FILE> ) ) 
			{
				print OUTPUT_FILE $line;
			}

			close INPUT_FILE;
			close OUTPUT_FILE;
		}
		else
		{
## 
## If no archived file, we can simply move the current version
##
			DEBUG( "archive current $REMOTEFILE\n" );
			move( "$INDIR/$REMOTEFILE", 
				"$INDIR/$ARCHIVE/$REMOTEFILE.$DATESTAMP" );
		}
	}
	
	###
	### Change directories
	###
	DEBUG( "changing directories to $REMOTEDIR...\n" );
	$ftp->cwd("$REMOTEDIR") or
		EXIT( "Can not CWD to: $REMOTEDIR: $!\n" );

	###
	### Check for remote file and send alerts if not present
	###
#	DEBUG( "checking remote file size...\n" );
#	$ftp->size("$REMOTEFILE") or
		
	
	###
	### Transfer file
	###
	DEBUG( "transfering file $REMOTEFILE...\n" );
	$ftp->get("$REMOTEFILE", "$INDIR/$REMOTEFILE") or
		EXIT( "Can not GET $REMOTEFILE: $!\n" );
	
	
	###
	### Check Downloaded File
	###
	DEBUG( "Checking downloaded file size...\n" );
	if( -s "$INDIR/$REMOTEFILE" )
	{
	
		###
		### Delete remote file per specs
		###
		DEBUG( "deleting file $REMOTEFILE...\n" );
		$ftp->delete($REMOTEFILE) or
			EXIT( "Error deleting $REMOTEFILE: $!\n" );
	}
}

if( $opt_u )
{
	###
	### Change directories
	###
	DEBUG( "changing directories to $REMOTEPUT...\n" );
	$ftp->cwd("$REMOTEPUT") or
		EXIT( "Can not CWD to: $REMOTEPUT: $!\n" );

	##
	## Loop through arrays from above and transfer files
	##
	foreach $i ( @DSNO )
	{
		DEBUG( "Transfering file: $OUTDIR/$i\n" );
		$ftp->put("$OUTDIR/$i") or
			EXIT( "Can not PUT $REMOTEPUT/$i: $ftp->message\n" );
		ARCHIVE( "$OUTDIR/$i", 
			"$OUTDIR/$ARCHIVE/DSNO.$DATESTAMP.ARC" );
		DEBUG( "Deleting file: $OUTDIR/$i\n" );
		unlink( "$OUTDIR/$i" );
	}
	foreach $i ( @INO )
	{
		DEBUG( "Transfering file: $OUTDIR/$i\n" );
		$ftp->put("$OUTDIR/$i") or
			EXIT( "Can not PUT $REMOTEPUT/$i: $ftp->message\n" );
		ARCHIVE( "$OUTDIR/$i", 
			"$OUTDIR/$ARCHIVE/INO.$DATESTAMP.ARC" );
		DEBUG( "Deleting file: $OUTDIR/$i\n" );
		unlink( "$OUTDIR/$i" );
	}
	foreach $i ( @ECE_POAO )
	{
		DEBUG( "Transfering file: $OUTDIR/$i\n" );
		$ftp->put("$OUTDIR/$i") or
			EXIT( "Can not PUT $REMOTEPUT/$i: $ftp->message\n" );
		ARCHIVE( "$OUTDIR/$i", 
			"$OUTDIR/$ARCHIVE/ECE_POAO.$DATESTAMP.ARC" );
		DEBUG( "Deleting file: $OUTDIR/$i\n" );
		unlink( "$OUTDIR/$i" );
	}

	##
	## Now we need to archive files
	##
	## 12/13/11 
	## - dwellman
	## Archive was moved above to just after file transfer.  Previous method ended up with 
	## duplicate transfers if the ftp process timed out in the middle of the file list.  
	## The script would immediately exit not having archived any files yet.  On next run it
	## would start the list over and resend all files.
	##

###	if( @DSNO )
###	{
###		DEBUG( "Archive files: @DSNO\n" );
####		system( "cd $OUTDIR; /usr/bin/tar cf - @DSNO | /usr/bin/gzip > $OUTDIR/$ARCHIVE/DSNO.$DATESTAMP.tar.gz" );
###		foreach $i ( @DSNO )
###		{
###			ARCHIVE( "$OUTDIR/$i", 
###				"$OUTDIR/$ARCHIVE/DSNO.$DATESTAMP.ARC" );
###			DEBUG( "Deleting file: $OUTDIR/$i\n" );
###			unlink( "$OUTDIR/$i" );
###		}
###	}
###	if( @INO )
###	{
###		DEBUG( "Archive files: @INO\n" );
####		system( "cd $OUTDIR; /usr/bin/tar cf - @INO | /usr/bin/gzip > $OUTDIR/$ARCHIVE/INO.$DATESTAMP.tar.gz" );
###		foreach $i ( @INO )
###		{
###			ARCHIVE( "$OUTDIR/$i", 
###				"$OUTDIR/$ARCHIVE/INO.$DATESTAMP.ARC" );
###			DEBUG( "Deleting file: $OUTDIR/$i\n" );
###			unlink( "$OUTDIR/$i" );
###		}
###	}
###	if( @ECE_POAO )
###	{
###		DEBUG( "Archive files: @ECE_POAO\n" );
####		system( "cd $OUTDIR; /usr/bin/tar cf - @ECE_POAO | /usr/bin/gzip > $OUTDIR/$ARCHIVE/ECE_POAO.$DATESTAMP.tar.gz" );
###		foreach $i ( @ECE_POAO )
###		{
###			ARCHIVE( "$OUTDIR/$i", 
###				"$OUTDIR/$ARCHIVE/ECE_POAO.$DATESTAMP.ARC" );
###			DEBUG( "Deleting file: $OUTDIR/$i\n" );
###			unlink( "$OUTDIR/$i" );
###		}
###	}
		
}

$ftp->quit;

print LOG<<EOF;
=========================================
END LOG
=========================================
EOF

close( LOG );


sub EXIT
{
	print STDERR @_;
	print LOG @_;
	print LOG<<EOF;
=========================================
END LOG
=========================================
EOF
	close( LOG );
	exit 1;
}

sub DEBUG
{
	print STDERR "DEBUG: " . "@_" if $DEBUG;
	print LOG "DEBUG: " . "@_";
}

sub USAGE
{
	print "Usage: \t$0 [-v verbose] -d (for download)
\t$0 [-v verbose] -u (for upload)\n";
}

sub CLEANUP
{

	DEBUG( "moving @_ to cleanup area\n") ;
	move( "$OUTDIR/@_", "/path/outbound/cleanup/" );
}

sub ARCHIVE
{
	my( $IN, $OUT ) = @_;
	DEBUG( "Archiving file $IN to $OUT\n");
	
	open INPUT_FILE, "< $IN" or
		EXIT("ERROR: can't open: $IN\n");
	open OUTPUT_FILE, ">> $OUT" or
		EXIT("ERROR: can't open: $OUT\n");

	while ( defined ( my $line = <INPUT_FILE> ) ) 
	{
		print OUTPUT_FILE $line;
	}

	close INPUT_FILE;
	close OUTPUT_FILE;

}
