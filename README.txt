convert.pl

Change Log:
-----------
2016-06-21 Pondy60 Initial creation.

MAPS
----

The maps file will be a csv file written from a spreadsheet having the input columns names running down the first column on the left side and having the standard output column names running across the top row.

If this is a multi-line file:
	Unique ID: You will need to append an asterisk inside parentheses (*) after the input column name that contains the unique identifier (like employee id or SSN) that indicates when multiple rows need to merge into a single output row.
	Selection Key: You will need to append a pound sign inside parentheses (#) after the input column name that will act as the selector value that shows the row record type.

At the intersection of the input column name and the output column name enter rules and/or a priorty separated with blanks.

NOTE: If you are starting from scratch with a new export file format, you can use the mapgen.pl program to generate a sample map file.  The syntax is "mapgen.pl NameOfFileInExportDirectory.csv".

RULES
-----

any number by itself is a priorty.  Bigger priorities will overwrite smaller priorities in the event that more than one input column is mapped to the same output column and an input row has more than one non-blank.
text.   Strip input quote characters (defined as $IQOT in the convert.pl program) if present and then enclose in output quoting characters (defined as $OQOT in the convert.pl program)
number. Strip input quote characters (defined as $IQOT in the convert.pl program) if present
	(if neither text nor number is specified, don't quote anything that looks like a number, but quote everything else.)
upper.  Force output to UPPER case.
lower.  Force output to lower case.
proper. Capitalize.
lname.  Split Last Name, First Name on comma and store the last name into this column
fname.  Split Last Name, First Name on comma and store the first name into this column
chg(from1=to1,from2=to2,from3=to3).  Compare the value to be moved to each of the from# values.  If matched, replace with the corresponding to# value.  Example: chg(S=Single,M=Married).
keep(selectorvalue).  Only move this input row to the output file if this row's selector column matches the value inside the parenthesis. 
key(selectorvalue).  Only move this input column to the selected output column if this row's selector column matches the value inside the parenthesis. 
key([columnreference]).  Only move this input column to the selected output column if this row's selector column matches the value of the input column named between the [square brackets].
	Example:
	Input\Output,Employee ID,Last Name,First Name,Federal Filing Status,State,Federal Allowances,State Allowances
	Employee ID(*),key(FedW) trim,,,,,,
	Last Name,,key(FedW),,,,,
	First Name,,,key(FedW),,,,
	tcode(#),,,,,,,
	Federal Filing Status,,,,key(FedW) chg(S=Single,M=Married),,,
	State,,,,,key(FedW),,
	exemptions,,,,,,key(FedW) trim,key([State]) trim
	
	NOTE: Rows with the same value in Employee ID column are to be combined into a single output row.  Rows for the same Employee ID and that have the value FedW in the tcode column contain Federal Withholding Exemptions in the Exemption column.  Those with a value that matches the contents of the State column contain the State Exemptions.  When the Employee ID vlue changes in the next row, the merged output row is written.

We can invent new rules for any other processing we want to do before outputting as we encounter things that don't convert exactly how they need to.

RUNNING THE CONVERSION
----------------------

To run the conversion open a command prompt (Window Key-R then enter cmd and click Ok).  Change the directory to whereever the program was stored.  I'm going to suggest a directory named convert under your documents directory.  If so the command would be:
cd %userprofile%\documents\converter
within that directory we will create three subdirectories:
	exports
	maps
	imports
When you export a csv file from the old system, store it into the exports directory.  That will be the main input file to each program.
You can use the mapgen.pl program to create a map file in the maps directory, but you will just get a copy of your input file if you don't modify the generated map.
The output of the convert.pl program will be written in the imports directory.
Use the csv file from the import directory to be imported into the new system.
