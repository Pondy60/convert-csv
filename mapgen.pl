use strict;

my $DEBUG = 0;	# 1 = output extra messages.  0 = output just required messages
my $ISEP = ',';	# This characters is what the export file used as a column separator 
my $OSEP = ',';	# This characters is what the import file needs as a column separator 
my $IQOT = '"';	# This characters is what the export file used to quote text
my $OQOT = '"';	# This characters is what the import file needs as quotes around text
my $MAXCOLS = 9999;

my @rules;
my (@icols,%icol,@ocols,@opriority,%ocol,@rnames,@inames,@onames,@r2i,%name2icol,$col,$rcol,$icol,$icols,$ocol,$opriority,$ocols,$colname,$colnum,$keycolname,$keycolnum,$keycolval,$idcolname,$idcolnum,$idcolval,$previdcolval);
my $num_cols_out = 0;

my ($infile,$mapfile,$logfile,$filebase);
my ($i, $row, $line, @word, $temp, $ovalue);

my $inpath = 'exports/';
my $mappath = 'maps/';

my @files = @ARGV;	# can optionally include file names to process (separated by space) containing optional asterisks as wildcard characters, otherwise all .csv files within exports/ directory will be procesed
die "Must specify at least one export file on command line.\n$!" unless scalar(@files);

&logmsg("Files to be processed:");
foreach $infile (@files) {
	&logmsg("$infile");
}

foreach $infile (@files) {
    $infile =~ /(.+)\.csv$/;
    $filebase = $1;
	die "Invalid input filename '$infile'.  Must end in '.csv'.\n$!" unless($filebase);	# get file basename (part before .csv but after directory path)

    $logfile = $filebase . '-log.txt';
    open LOG,">$logfile" or die "Unable to open $logfile for output.\n$!";
    &logmsg("\nLogging to $logfile");
	$infile = $inpath . $infile;
	$mapfile = $mappath . $filebase . '-map.csv';
    &logmsg("\nGenerating empty map into $mapfile based on contents of $infile.\n");

    open IN,"<$infile" or die "Unable to open $infile for input.\n$!";
    $line = <IN>;
    chomp $line;
    close IN;

    @inames = &get_row($line);

    open MAPOUT,">$mapfile"  or die "Unable to open $mapfile for output.\n$!";
    print MAPOUT 'Input\Output,' . join(',',@inames) . "\n";
    my $count = 1;
    foreach $line (@inames) {
        print MAPOUT "$line" . ',' x $count++ . "1\n";
    }
    close MAPOUT;
    &logmsg("$mapfile written");
    close LOG;
}

sub get_row {
	my ($line) = @_;
	my @cols;
	my $loopcount = $MAXCOLS;
	my $colnum = 0;
	&logmsg("Get Columns from Row: $line") if ($DEBUG);
	while ($line) {
		$line =~ s/^((?!$IQOT)[^$ISEP]*|$IQOT([^$IQOT]|$IQOT$IQOT)*$IQOT)($ISEP|$)//g;
		push @cols,$1;
		$cols[-1] =~ s/^$IQOT(.*)$IQOT$/$1/;
		die "Debugging - More than $MAXCOLS columns." if (--$loopcount < 1);
	}
	$idcolval = $cols[$idcolnum] if ($idcolname);
	$keycolval = $cols[$keycolnum] if ($keycolname);
	foreach (@cols) {
		&logmsg("  $_") if ($DEBUG);
	}
	return @cols;
}

sub logmsg {
	my ($line) = @_;
	print LOG "$line\n";
	print "$line\n";
	return;
}

sub unquote {
	my ($instring) = @_;
	my $outstring = '';
	&logmsg("Unquoting: '" . $instring . "'") if($DEBUG);
	$outstring = $instring;
	$outstring =~ s/^$IQOT(.*)$IQOT$/$1/;
	$outstring =~ s/$IQOT$IQOT/$IQOT/g;
	&logmsg("Unquoted: '" . $outstring . "'") if($DEBUG);
	return $outstring;
}

sub quote {
	my ($instring) = @_;
	my $outstring = &unquote($instring);
	$outstring =~ s/$OQOT/$OQOT$OQOT/g;
	$outstring = $OQOT . $outstring . $OQOT;
	&logmsg("Quoted text: '" . $outstring . "'") if($DEBUG);
	return $outstring;
}