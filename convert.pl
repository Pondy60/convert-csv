use strict;

my $DEBUG = 0;	# 1 = output extra messages.  0 = output just required messages
my $RSEP = ",";	# This character is what the map file used as a column separator 
my $ISEP = ",";	# This character is what the export file used as a column separator 
my $OSEP = ',';	# This characters is what the import file needs as a column separator 
my $IQOT = '"';	# This characters is what the export file used to quote text
my $OQOT = '"';	# This characters is what the import file needs as quotes around text
my $MAXCOLS = 9999;

my @rules;
my (@icols,%icol,@ocols,@opriority,%ocol,@rnames,@inames,@onames,@r2i,%name2icol,$col,$rcol,$icol,$icols,$ocol,$opriority,$ocols,$colname,$colnum,$keycolname,$keycolnum,$keycolval,$idcolname,$idcolnum,$idcolval,$previdcolval);
my $num_cols_out = 0;
my $idtag = '(*)';
my $keytag = '(#)';

my ($infile,$outfile,$mapfile,$logfile,$filebase);
my ($i, $row, $line, @word, $temp, $ovalue, $keyval, $value, $from, $to);

my $inpath = 'exports/';
my $mappath = 'maps/';
my $outpath = 'imports/';

my @files = @ARGV;	# can optionally include file names to process (separated by space) containing optional asterisks as wildcard characters, otherwise all .csv files within exports/ directory will be procesed
unless (scalar(@files)) {
	@files = glob $inpath . '*';
}

&logmsg("Files to be processed:");
foreach $infile (@files) {
	@word = split /[\\\/]/,$infile;
	$infile = $word[-1];
	&logmsg("$infile");
}

foreach $infile (@files) {
	$infile =~ /(.+)\.csv$/;	# get file basename (part before .csv but after directory path)
	$filebase = $1;
	$infile  = $inpath .  $infile;
	$mapfile = $mappath . $filebase . '-map.csv';
	$outfile = $outpath . $filebase . '-import.csv';
	$logfile = $filebase . '-log.txt';
	open LOG,">$logfile" or die "Unable to open $logfile for output.\n$!";
	&logmsg("\nLogging to $logfile");
	&get_rules($mapfile);
	&logmsg("Writing output to $outfile");
	open OUT,">$outfile" or die "Unable to open $outfile for output.\n$!";
	print OUT $OQOT . join($OQOT . $OSEP . $OQOT,@onames) . $OQOT . "\n";
	&logmsg("Reading input from $infile\n");
	open IN,"<$infile" or die "Unable to open $infile for input.\n$!";
	$line = <IN>;
	chomp $line;
	@inames = &get_row($ISEP, $line);
	for ($icol = 0; $icol < scalar(@inames); $icol++) {
		$name2icol{$inames[$icol]} = $icol;
		if ($inames[$icol] eq $idcolname) {
			$idcolnum = $icol;
		}
		if ($inames[$icol] eq $keycolname) {
			$keycolnum = $icol;
		}
	}
	for ($rcol = 0; $rcol < scalar(@rnames); $rcol++) {
		if (exists($name2icol{$rnames[$rcol]})) {
			$r2i[$rcol] = $name2icol{$rnames[$rcol]};
		} else {
			&logmsg("Map $mapfile contains rule for input column named $rnames[$rcol], but input file $infile does not have a column with that name.  You may need to change the \$ISEP value in convert.pl");
			die "Map $mapfile contains rule for input column named '$rnames[$rcol]', but input file $infile does not have a column with that name.  You may need to change the \$ISEP value in convert.pl";
		}
		
	}
	$row = 1;
inrec:
   while (<IN>) {
		chomp;
		$line = $_;
		@icols = &get_row($ISEP, $line);
		unless ($idcolname and ($idcolval eq $previdcolval)) {
			&put_row if (@ocols);
		}
		$previdcolval = $idcolval;
		for ($rcol = 0; $rcol < scalar(@rnames); $rcol++) {
			$icol = $r2i[$rcol];
			for ($ocol = 0; $ocol < $num_cols_out; $ocol++) {
				if ($rules[$icol][$ocol]) {	# if a rule exists, process it
					$ovalue = $icols[$icol];
					# keep: only keep records whose key column value matches key value selector
					if ($rules[$icol][$ocol] =~ /\bkeep\(([^)]+)\)/i) {
						$keyval = $1;
						if ($keycolval ne $keyval) {
						   &logmsg("Dropping record for unmatched key: $keycolval ne $keyval");
						   undef @ocols;	# reset output columns for a new row
							next inrec;    # skip this row
						}
					}
					# trim: force upper case
					if ($rules[$icol][$ocol] =~ /\btrim\b/i) {
						$ovalue = &trim(&unquote($ovalue));
					}
					# upper: force upper case
					if ($rules[$icol][$ocol] =~ /\bupper\b/i) {
						$ovalue = uc($ovalue);
					}
					# lower: force lower case
					if ($rules[$icol][$ocol] =~ /\blower\b/i) {
						$temp = $1;
						$ovalue = lc($ovalue);
					}
					# proper: force Title text (initial capitals)
					if ($rules[$icol][$ocol] =~ /\bproper\b/i) {
						$temp = $ovalue;
						$ovalue = '';
						&logmsg("Proper temp = '$temp', ovalue = '$ovalue'") if($DEBUG);
						while ($temp =~ s/^([^ ,-]+)([ ,-]+|$)//g) {
							&logmsg("Proper word = '$1', space = '$2'") if($DEBUG);
							$ovalue .= uc(substr($1,0,1)) . lc(substr($1,1)) . $2;
							&logmsg("Proper temp = '$temp', ovalue = '$ovalue'") if($DEBUG);
						}
					}
					# lname: split Last Name, First Name on comma and store Last Name into this column
					if ($rules[$icol][$ocol] =~ /\blname\b/i) {
						@word = split /,/,$ovalue;
						$ovalue = shift @word;
					}
					# fname: split Last Name, First Name on comma and store First Name into this column
					if ($rules[$icol][$ocol] =~ /\bfname\b/i) {
						@word = split /,/,$ovalue;
						shift @word;
						$ovalue = join ',',@word;
					}

					# chg: change one value to another
					if ($rules[$icol][$ocol] =~ /\bchg\(([^)]+)\)/i) {
						$temp = $1;
						@word = split /,/,$temp;
						foreach $value (@word) {
							($from,$to) = split /\=/,$value;
							if ($ovalue eq $from) {
								$ovalue = $to;
								last;
							}
							
						}
					}

					#	-----------------------------------
					#	To Quote or Not to Quote.  Pick one
					#	-----------------------------------
					# number: force treatment as number (remove enclosing quote characters $IQOT if present)
					if ($rules[$icol][$ocol] =~ /\bnumber\b/i) {
						$ovalue = &unquote($ovalue);
					}
					# text: force treatment as text (enclose in quote characters $OQOT)
					elsif ($rules[$icol][$ocol] =~ /\btext\b/i) {
						&logmsg("Quoting: '" . $ovalue . "'") if($DEBUG);
						$ovalue = &quote($ovalue);
					}
					# if it looks like a number, don't quote it
					elsif ($ovalue =~ /^-?(?:\d+\.?|\.\d)\d*\z/) {
						$ovalue = &unquote($ovalue);
					}
					# otherwise quote it
					else {
						&logmsg("Quoting: '" . $ovalue . "'") if($DEBUG);
						$ovalue = &quote($ovalue);
					}

					# 1 (or 2, 3, etc): set output priority
					if ($rules[$icol][$ocol] =~ /\b(\d+)\b/i) {
						$opriority = $1;
					} else {
						$opriority = 0;
					}
					# key: detect collision and move to output column if okay
					if ($rules[$icol][$ocol] =~ /\bkey\(([^)]+)\)/i) {
						$keyval = $1;
						if ($keyval =~ /^\[(.+)\]$/) {
							$keyval = $icols[$name2icol{$1}];
						}
						if ($keycolval eq $keyval) {
							&set_ocol;
						}
					} else {
						&set_ocol;
					}
				}	# rule exists
			}	# for each output column
		}	# for each input column
	}	# for each line within the input file
	&put_row if (@ocols);	
	close IN;
	close OUT;
	close LOG;
}

sub put_row {
	return unless(scalar(@ocols));
	for (my $i = 0; $i < $num_cols_out; $i++) {
		$ocols[$i] = '' unless ($ocols[$i]);
	}
	&logmsg("Output Columns:") if ($DEBUG);
	foreach (@ocols) {
		&logmsg("  $_") if ($DEBUG);
	}
	print OUT join($OSEP,@ocols) . "\n";
	undef @ocols;	# reset output columns for a new row
}

sub get_row {
	my ($sep, $line) = @_;
	my @cols;
	my $loopcount = $MAXCOLS;
	my $colnum = 0;
	&logmsg("Get Columns from Row: $line") if ($DEBUG);
	while ($line) {
		$line =~ s/^((?!$IQOT)[^$sep]*|$IQOT([^$IQOT]|$IQOT$IQOT)*$IQOT)($sep|$)//g;
		push @cols,$1;
		$cols[-1] =~ s/^$IQOT(.*)$IQOT$/$1/;
		die "Debugging - more than $MAXCOLS columns!" if (--$loopcount < 1);
	}
	$idcolval = $cols[$idcolnum] if ($idcolname);
	$keycolval = $cols[$keycolnum] if ($keycolname);
	foreach (@cols) {
		&logmsg("  $_") if ($DEBUG);
	}
	return @cols;
}

sub get_rules {
	my ($mapfile) = @_;
	my (@cols);
	open MAPIN,"<$mapfile" or die "Unable to open $mapfile for input.\n$!";
	&logmsg("Reading rules from $mapfile");
	$line = <MAPIN>;
	chomp $line;
	@onames = &get_row($RSEP, $line);
	shift @onames;	# drop cell A1 since it is just "input\output"
	$num_cols_out = scalar(@onames);
	$rcol = 0;
	undef @rnames;
	while (<MAPIN>) {
		chomp;
		$line = $_;
		@cols = &get_row($RSEP,$line);
		$colname = shift @cols;
		if (substr($colname, 0-length($keytag), length($keytag)) eq $keytag) {
			$colname = substr($colname, 0, length($colname) - length($keytag));
			$keycolname = $colname;
		}
		if (substr($colname, 0-length($idtag),length($idtag)) eq $idtag) {
			$colname = substr($colname, 0 ,length($colname) - length($idtag));
			$idcolname = $colname;
		}
		push @rnames,$colname;
		@{ $rules[$rcol] } = @cols;
		$rcol++;
	}
	close MAPIN;
	&logmsg("Rules read.") if ($DEBUG);
}

sub logmsg {
	my ($line) = @_;
	print LOG "$line\n";
	print "$line\n";
	return;
}

sub colnum2letter {
	my ($num) = @_;
	my $letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	my $base = length($letters);
	my $string = '';
	my $digit;
	while ($num) {
		$digit = $num % $base;
		$string = substr($letters,$digit,1) . $string;
		$num = int($num / $base);
	}
	$string = 'A' unless ($string);
	return $string;
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

sub trim {
	my ($instring) = @_;
	my $outstring = '';
	&logmsg("Trimming: '" . $instring . "'") if($DEBUG);
	$outstring = $instring;
	$outstring =~ s/(^\s+|\s+$)//g;
	&logmsg("Trimmed: '" . $outstring . "'") if($DEBUG);
	return $outstring;
}

sub set_ocol {
	if (defined($ocols[$ocol])) {
		if ($opriority > $opriority[$ocol]) {
			&logmsg("Overwriting " . $ocols[$ocol] . " with " . $ovalue . " due to higher priority (" . $opriority . " > " . $opriority[$ocol] . ")") if ($DEBUG);
			$ocols[$ocol] = $ovalue;
		} else {
			&logmsg("Collision on row: $row, for input column: " .
					&colnum2letter($icol) . " with value(" . $ovalue . ") trying to go to output column " . &colnum2letter($ocol) .
					" but that column already contains value(" . $ocols[$ocol] . ") with an equal or higher priority [" .
					($opriority[$ocol] + 0) . " >= " . ($opriority + 0) . "]");
		}
	} else {
		&logmsg("Writing '$ovalue' from input column " . &colnum2letter($icol) . " to output column " . &colnum2letter($ocol)) if ($DEBUG);
		$ocols[$ocol] = $ovalue;
	}
	$opriority[$ocol] = $opriority;
}