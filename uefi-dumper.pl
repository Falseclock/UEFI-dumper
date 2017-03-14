#!/usr/bin/perl
#
# Copyright (c) 2013 Nurlan Mukhanov (aka Falseclock) <nurike@gmail.com>
#
# Please inform me if you found error/mistakes or enhance this script.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
 
$| = 1;
 
use strict;
use warnings;
use utf8;
use Encode;
use Data::Dumper;
use vars qw($ROM $ROM_SIZE $IFR_PACKAGE_SIG @EFI_HII_PACKAGES %EFI_HII_PACKAGE_TYPE %LANGUAGES @EFI_HII_PACKAGE_FORMS %EFI $DEFAULT_LANGUAGE @STRINGS @TABS %TYPES);
 
################### !!! IMPORTANT !!! ###################
$IFR_PACKAGE_SIG = '$IFRPKG!';
#########################################################
 
$DEFAULT_LANGUAGE = 'en-US';
my $file = $ARGV[0] || "Setup.rom";
 
&SPECIFICATION_LOAD();
 
#---------------------------- MAIN PROGRAMM ----------------------------#
 
open($ROM, "<$file ") or die "ERROR : Cannot open $file.\n";
{
	binmode $ROM;
	undef $/;
	$ROM_SIZE = -s $file;
}
 
#--------------------------------------------------------------------
# 1. Search IFR virtual package
my $header_offset = &IFR_PACKAGE_SIG();
print STDERR "IFR_PACKAGE_SIG not found!\nExiting programm...\n" and exit 1 if (!$header_offset);
 
#--------------------------------------------------------------------
# 2. Search EFI_HII_PACKAGE_HEADERs
@EFI_HII_PACKAGES = &EFI_HII_PACKAGES($header_offset);
 
 
#--------------------------------------------------------------------
# 3. Parse EFI_HII_PACKAGE_STRINGS
#print "Parsing language tables..\n";
%LANGUAGES = &EFI_HII_PACKAGE_STRINGS();
#printf "\tFound %d languages: %s\n", scalar keys %LANGUAGES, join ', ', sort keys %LANGUAGES;
@STRINGS = @{$LANGUAGES{$DEFAULT_LANGUAGE}->{'strings'}};
 
#print Dumper(\@STRINGS);
#print Dumper(\%LANGUAGES);
 
=head
# 3.1. Check languages length
my %length;
$length{$_} = scalar @{$LANGUAGES{$_}->{'strings'}}  foreach (keys %LANGUAGES);
 
my $warn = 0;
 
foreach (keys %length)
{
	next if $_ eq 'en-US';
	
	if ($length{$_} != $length{'en-US'})
	{
		if (!$warn)
		{
			printf STDERR "\tWARNING: languages array length is different, must be %d elements:\n", $length{'en-US'};
			$warn = 1;
		}
		printf "\t\t%s: (%d)\n", $_, $length{$_} - $length{'en-US'};
	}
}
=cut
#--------------------------------------------------------------------
# 4. FORM packages parsing
@EFI_HII_PACKAGE_FORMS = &EFI_HII_PACKAGE_FORMS();
 
close($ROM); 
 
#-----------------------------------------------------------------------#
#-----------------------------------------------------------------------#
 
sub str2hex {
	return unpack ("H*", shift);
}
 
sub dec2bin {
    return unpack("B32", pack("N", shift));
}
 
sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}
 
sub oplength {
	my $data = shift;
	my $length = unpack("C", $data);
	
	return bin2dec(substr &dec2bin($length), -7);
	
}
 
sub EFI_IFR {
	my $data = shift;
	my $length = length($data);
	
	my @opcodes;
	
	#printf "length: %d, hex: %s\n", length($data), join (' ', unpack("(H2)*",substr($data,0,10)));
	
	my $i = 0;
 
	while ($i < $length)
	{
		my %op;
		
		# Reading OPCODE
		$op{'opcode'} = unpack("C", substr($data,$i,1));
		$i++;
		
		# Reading length
		$op{'length'} = oplength(substr($data,$i,1));
		$i++;
 
		# Reading payload
		$op{'payload'} = substr($data,$i,$op{'length'}-2);
		$i += $op{'length'} -2;
 
		# Setting indent
		#$op{'indent'} = $INDENTS{$op{'opcode'}};
	
		push @opcodes, \%op;
		
#		printf "Opcode: %02X, Length: %d\n",$op{'opcode'} , $op{'length'};
#		my $www = <STDIN>;
	}
		
	return \@opcodes;
}
 
sub EFI_HII_PACKAGE_FORMS {
	my @forms = ();
	
	#print Dumper(\@EFI_HII_PACKAGES);
	
	foreach (@EFI_HII_PACKAGES)
	{
		my %pkg = %{$_};
		my %form;
		if ($_->{type} == 0x02)
		{
			# printf "EFI_HII_PACKAGE_FORMS offset int : %d, hex: (0x%08x)\n",$pkg{'int_offset'},$pkg{'int_offset'};
			# Skeep first 4 bytes of FULLL_PACKAGE_LENGTH
					
			my $FORM_PACKAGE_LENGTH = unpack('I', (data($pkg{int_offset} + 4, 3).pack("H",0))   );
			my $FORM_PACKAGE_TYPE = unpack('C', (data($pkg{int_offset} + 7, 1))   );
 
			$form{'length'} = $FORM_PACKAGE_LENGTH;
			$form{'type'} = $FORM_PACKAGE_TYPE;
			
			#printf "  Form length: %s, type: %s\n", $FORM_PACKAGE_LENGTH, $FORM_PACKAGE_TYPE;
			
			my $op_offset = $pkg{int_offset} + 8;
			my $op_length = ($FORM_PACKAGE_LENGTH - 4);
			
			$form{'opcodes'} = &EFI_IFR(data($op_offset,$op_length));
			$form{'package'} = $_;
			
			push @forms, \%form;
		}
	}
	
	&EFI_IFR_FORM_SET(\@forms);
	#print Dumper(\@forms);
	
	return @forms;
}
 
sub EFI_IFR_FORM_SET {
	my $forms = shift;
	my @forms = @{$forms};
	
	#print Dumper(\@forms);
	
	foreach my $form (@forms)
	{
		my %form = %{$form};
		my @ops = @{$form{'opcodes'}};
		
		foreach (@ops)
		{
			my %op = %{$_};
			&EFI_IFR_PRINT(\%op,\%{$form{'package'}});
		}
		print "\n";
	}
}
 
sub fguid {
	my $guid = shift;
	
	my ($a, $b, $c, $d, $e);
	
	$a = unpack("H*",scalar reverse(substr($guid,0,4)));
	$b = unpack("H*",scalar reverse(substr($guid,4,2)));
	$c = unpack("H*",scalar reverse(substr($guid,6,2)));
	$d = unpack("H*",substr($guid,8,2));
	$e = unpack("H*",substr($guid,10,6));
	
	return sprintf("%s-%s-%s-%s-%s",$a,$b,$c,$d,$e);
}
 
sub EFI_HII_PACKAGE_STRINGS {
	my %pkg;
	
	foreach (@EFI_HII_PACKAGES)
	{
		%pkg = %{$_} and last if ($_->{type} == 0x04);
	}
	
	my $reader= 4;  # current reading offset
	
	my %languages;
	
	while ($reader < $pkg{size}) # read until we in package
	{
		my $LANG_PACKAGE_LENGTH = unpack('I', (data($pkg{int_offset} + $reader, 3).pack("H",0))   );
		my $LANG_PACKAGE_OFFSET = $pkg{int_offset} + $reader;
		
		#print $LANG_PACKAGE_LENGTH,"\n";
		
		if ($LANG_PACKAGE_LENGTH)
		{
			$reader += (3 + 1 + 42);
			
			my $LANG_PACKAGE_NAME = (data($pkg{int_offset} + $reader, 5)); # skip 00 - end of header
			
			$languages{$LANG_PACKAGE_NAME} = {'offset' => $LANG_PACKAGE_OFFSET, 'length' => $LANG_PACKAGE_LENGTH, 'name' => $LANG_PACKAGE_NAME };
		}
		
		$reader += $LANG_PACKAGE_LENGTH - (3 + 1 + 42);
	}
	
	foreach (keys %languages)
	{
		my %lang = %{$languages{$_}};
		
		#print "Reading language from offset: ".$lang{'offset'}."\n";
		#print "Language name is: ".$lang{'name'}."\n";
		
		my $table = data($lang{'offset'}+46+6, $lang{'length'} - 46 - 6);
	
		my @table = unpack('(H2)*',$table);
		
		# As beginning  of string contains type
		# and we can't split whole string, let's read byte by byte
 
		my @strings;
		my $position=0;
		my $word = undef;
		my $eof = 0;
		my $last = undef;
		my $skip = 0;
		my $word_start = 0;
		push @strings, undef;	# MEMEORY OFFSET CAN NOT BE 0
		
		my %EFI_HII_STRING_BLOCK = map { $_ => 1 } ('10', '11', '12', '13', '15', '16', '17', '22', '30', '31', '32', '40');
		
		for (my $l=0; $l < $#table; $l++)
		{
			my $byte = $table[$l];
			
			if ( exists($EFI_HII_STRING_BLOCK{$byte}) && !$word && $last ne '14')
			{
				print STDERR "Unexpected EFI_HII_STRING_BLOCK -> BlockType = $byte found!\n";
				printf STDERR "String offset: %d (0x%08x)\n", $lang{'offset'} + $l, $lang{'offset'} + $l;
				
				exit 1;
			}
			
			$last = $byte and $word_start = 1 and next if ($byte eq '14');		# EFI_HII_SIBT_STRING_UCS2
 
			if ($byte eq '21' && !$word && !$word_start )					# EFI_HII_SIBT_SKIP2
			{
				#print "SKEEP FOUND\n";
				$skip = hex($table[$l+1]);					# number of skips
				$l += 2;									# pass reading @table for next 2 bytes
				
				while ($skip)
				{
					push @strings, "EFI_HII_SIBT_SKIP2-$skip";
					$skip--;
				}
				next;
			}
			
			if ($byte eq '20' && !$word && !$word_start  )					# EFI_HII_SIBT_DUPLICATE
			{
				push @strings, $strings[$#strings];
				$l += 3;
				next;
			}
			
			# If word end
			if ($byte eq '00' && $table[$l+1] eq '00')
			{
				#print $word."\n";
				
				push @strings, $word;
				
				$word = undef;
				$word_start = 0;
				$l++;
				next;
			}
			
			$word .= decode('utf-16le',pack("H*",$byte).pack("H*",$table[$l+1]));
			
			$l++;
		}
		$languages{$_}->{'strings'} = \@strings;
	}
 
	return %languages;
	#print Dumper(\%languages);
}
 
sub EFI_HII_PACKAGES {
	my $offset = shift;
	$offset += 8;
 
	my @address = ();
	
	while (1)
	{
		my $data = data($offset,8);
		my $hex = unpack("H*",$data);
		last if $hex !~ /^[ABCDEF0-9]{10}000000$/i;
		
		if ($hex =~ /^[ABCDEF0-9]{6}8001000000$/i)
		{
			push @address, substr ((join '', (reverse ($hex =~ m/../g))), 10);
			
			#my $address = substr ((join '', (reverse ($hex =~ m/../g))), 10);
			#printf "$address - %s\n", hex($address);
		}
		$offset += 8;
	}
	my @pkg = ();
	foreach (@address)
	{
		my %pkg;
		$pkg{int_offset} = hex($_);
		$pkg{hex_offset} = $_;
		$pkg{size} = unpack("I*",data(hex($_),4));
		$pkg{type} = unpack("C", data( hex($_)+7 , 1 ));
		$pkg{type_name} = $EFI_HII_PACKAGE_TYPE{$pkg{type}}->{name};
		$pkg{type_text} = $EFI_HII_PACKAGE_TYPE{$pkg{type}}->{text};
		
		push @pkg, \%pkg;
	}
	
	return @pkg;
}
 
sub IFR_PACKAGE_SIG {
	my $i = 0;
	my $offset = 0;
	my $seek = undef;
	my @sig = split //, $IFR_PACKAGE_SIG;
	
	while ($i <= $ROM_SIZE)
	{
		my $byte = data($i,1);
		#last unless $byte;
 
		# If we found start of header
		if ($byte eq '$')
		{
			$offset = $i;									# Store current offset
			$seek = $byte;									# Store begining of the signature
			$i++;
			next;
		}
		
		if ($offset)										# just to save CPU time
		{
			if (scalar grep $byte eq $_, @sig)
			{
				$seek .= $byte if ($IFR_PACKAGE_SIG =~ $seek.$byte );
				last if ($IFR_PACKAGE_SIG eq $seek );
			}
			else
			{
				$offset = 0;
				$seek = undef;
			}
		}
		$i++;
	}
	
	#printf "\nIFR_PACKAGE_SIG found at offset: %d (0x%08x)\n", ($offset, $offset) if $offset;
 
	return $offset;
}
 
sub data {
	my $offset = shift;
	my $length = shift;
	my $data;
	
	seek $ROM, $offset, 0; 
	sysread $ROM, $data, $length;
	
	return $data;
};
 
sub TabSpace {
	# Pushing 
	push @TABS, shift;
	
	return '    ' x (scalar @TABS - 1);
}
 
sub TabClose {
	my $length = scalar @TABS;
	my $return = "";
	
	if ($length)
	{
		my $opcode = pop @TABS;
	
		if ($opcode == $EFI{EFI_IFR_GRAY_OUT_IF_OP})
		{
			$return = sprintf "\xE2\x94\x94- END IF Grayout;\n";
		}
		elsif ($opcode == $EFI{EFI_IFR_SUPPRESS_IF_OP})
		{
			$return = sprintf "\xE2\x94\x94- END IF Suppress;\n";
		}
		else
		{
			$return = "What the fuck?";
		}
	}
	return $return;
}
 
sub EFI_IFR_PRINT
{
	my $op = shift;
	my $package = shift;
	my $TabSpace = '';
	
	my %op = %{$op};
	my %package = %{$package};
	
	if ($op{'opcode'} != $EFI{EFI_IFR_FORM_SET_OP} and scalar @TABS) {
		
		if ($op{'opcode'} == $EFI{EFI_IFR_SUPPRESS_IF_OP} or $op{'opcode'} == $EFI{EFI_IFR_GRAY_OUT_IF_OP})
		{
			$TabSpace = sprintf "|";
		}
		elsif ( $op{'opcode'} == $EFI{EFI_IFR_END_OP} )
		{
			$TabSpace = sprintf  "%s",'|    ' x (scalar @TABS - 1 );
		}
		else
		{
			$TabSpace = sprintf  "%s",'|    ' x (scalar @TABS);
		}
		
		print $TabSpace;
	}
 
	if    ($op{'opcode'} == $EFI{EFI_IFR_FORM_SET_OP})			{	# 0x0E
		my $Guid = substr($op{'payload'},0,16);
		my $FormSetTitle = unpack("S2",substr($op{'payload'},16,2));
		my $Help = unpack("S2",substr($op{'payload'},18,2));
		my $Flags = substr($op{'payload'},20,2);
		my $ClassGuid = substr($op{'payload'},22,16);
	
		printf "\n\xE2\x95\x94%s\xE2\x95\x97\n","\xE2\x95\x90"x116;
		printf "\x{E2}\x{95}\x{91} FormSet: '%-62sGUID: %s \xE2\x95\x91\n", ($STRINGS[$FormSetTitle]."'", fguid($Guid));
		printf "\x{e2}\x{95}\x{9f}%s\x{e2}\x{95}\x{a2}\n","\x{e2}\x{94}\x{80}"x116;
		
 
		if ($STRINGS[$Help] and $STRINGS[$Help] ne ' ')
		{
			printf " \\Help text: '%s'\n", $STRINGS[$Help];
		}
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_GUID_OP})				{	# 0x5F
		my $Guid = substr($op{'payload'},0,16);
		my $Data = unpack("H*", substr($op{'payload'},16));
		#printf "\x{E2}\x{95}\x{91} Operation data: '%-55sGUID: %s \xE2\x95\x91\n", $Data, &fguid($Guid);
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_DEFAULTSTORE_OP})		{	# 0x5C
		my $DefaultId = unpack("S2", substr($op{'payload'},2,2));
		my $DefaultName = unpack("S2", substr($op{'payload'},2,2));
		#printf "EFI_IFR_DEFAULTSTORE_OP, length: %d, DefaultId: %s, DefaultName: %s \n",length($op{'payload'}),$DefaultId,$DefaultName ;
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_VARSTORE_OP})			{	# 0x24
		# typedef struct _EFI_IFR_VARSTORE {
		#   EFI_IFR_OP_HEADER        Header;
		#   EFI_GUID                 Guid;
		#   EFI_VARSTORE_ID          VarStoreId;
		#   UINT16                   Size;
		#   UINT8                    Name[1];
		# } EFI_IFR_VARSTORE;
		#printf "EFI_IFR_VARSTORE_OP, length: %d \n",length($op{'payload'});
 
		my $Guid = substr($op{'payload'},0,16);
		my $VarStoreId = unpack("S2", substr($op{'payload'},16,2));
		my $Size = unpack("S2", substr($op{'payload'},18,2));
		my $Name = substr($op{'payload'},20,12);
		
		printf "\x{E2}\x{95}\x{91} VarStore Id: '0x%x', Size: '%s', Name: '%s'                GUID: %s \x{E2}\x{95}\x{91}\n", $VarStoreId, $Size, $Name, &fguid($Guid);
		printf "\xE2\x95\x9A%s\xE2\x95\x9D\n","\xE2\x95\x90"x116;
 
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_FORM_OP})				{	# 0x01
		my $FormId = unpack("S2",substr($op{'payload'},0,2));
		my $FormTitle = unpack("S2",substr($op{'payload'},2,2));
		printf "\x{e2}\x{94}\x{8c}%s\x{e2}\x{94}\x{90}\n","\x{e2}\x{94}\x{80}"x116;
		printf "\x{e2}\x{94}\x{82} Form Name: '%-86s [ ID: '0x%04x' ]\x{e2}\x{94}\x{82}\n", ($STRINGS[$FormTitle]."'", $FormId);
		printf "\x{e2}\x{94}\x{94}%s\x{e2}\x{94}\x{98}\n","\x{e2}\x{94}\x{80}"x116;
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_GRAY_OUT_IF_OP})		{	# 0x19
		printf "%s\x{E2}\x{94}\x{8C}- Grayout IF:\n",TabSpace($op{'opcode'});
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_SUPPRESS_IF_OP})		{	# 0x0A
		printf "%s\xE2\x94\x8C- Suppress IF:\n",TabSpace($op{'opcode'});
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_END_OP})				{	# 0x29
		printf "%s",&TabClose($op{'opcode'});
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_EQ_ID_VAL_OP})			{	# 0x12
		my $QuestionId =  unpack("S2",substr($op{'payload'},0,2));
		my $Value =  unpack("S2",substr($op{'payload'},2,2));
		printf "Question [ ID: '0x%02x' ] == 0x%02x\n", $QuestionId, $Value,;
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_AND_OP})				{	# 0x15
		printf "AND expression\n";
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_SUBTITLE_OP})			{	# 0x02
		my $Prompt = unpack("S2",substr($op{'payload'},0,2));
		my $Help = unpack("S2",substr($op{'payload'},2,2));
 
		printf "Subtitle: '%s'\n", ($STRINGS[$Prompt]) if defined $STRINGS[$Prompt] and $STRINGS[$Prompt] ne ' ';
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_DEFAULT_OP})			{	# 0x5B
		my $DefaultId = unpack("S2",substr($op{'payload'},0,2));
		my $Type = unpack("C",substr($op{'payload'},2,1));
		my $value;
		if ($Type == 0) {
			$value = unpack("C",substr($op{'payload'},3,1));
		} 
		elsif ($Type == 1) {
			$value = unpack("S2",substr($op{'payload'},3,2));
		}
		elsif ($Type == 2) {
			$value = unpack("S2",substr($op{'payload'},3,2));
		}
		elsif ($Type == 5) {
			$value = sprintf("%02d",unpack("C",substr($op{'payload'},3,1))).':'.sprintf("%02d",unpack("C",substr($op{'payload'},4,1))).':'.sprintf("%02d",unpack("C",substr($op{'payload'},5,1)));
		}
		elsif ($Type == 6) {
			$value = unpack("S2",substr($op{'payload'},3,2)).'/'.sprintf("%02d",unpack("C",substr($op{'payload'},5,1))).'/'.sprintf("%02d",unpack("C",substr($op{'payload'},6,1)));
		}
		else {
			$value = unpack("S*",substr($op{'payload'},3,4));
		}
		printf "  Default value: '%s', Type: 0x%02x\n",$value, $Type;
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_TRUE_OP})				{	# 0x46
		printf "EQ == TRUE\n";
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_FALSE_OP})				{	# 0x47
		printf "EQ == FALSE\n";
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_TEXT_OP})				{	# 0x03
		my $Prompt = unpack("S2",substr($op{'payload'},0,2));
		my $Help = unpack("S2",substr($op{'payload'},2,2));
		my $TextTwo = unpack("S2",substr($op{'payload'},4,2));
		my $t2 = "";
		$t2 = $STRINGS[$TextTwo] if (defined $STRINGS[$TextTwo]);
		printf "Text: '%-32.32sDefault: '%-32.32sHelp: '%s'\n", $STRINGS[$Prompt]."'", $t2."'", $STRINGS[$Help];
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_UINT64_OP})			{	# 0x45
		my $Value = $op{'payload'};
		printf "VALUE = %s\n", unpack("S*",$Value);
		
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_EQUAL_OP})				{	# 0x2F
		printf "EQUAL expression\n";
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_EQ_ID_LIST_OP})		{	# 0x14
 
		my $QuestionId = unpack("S2", substr($op{'payload'},0,2));
		my $ListLength = unpack("S2", substr($op{'payload'},2,2));
		my @ValueList = unpack("(S4)*", substr($op{'payload'},4));
		@ValueList = map {sprintf "'0x%02x'", $_ } @ValueList;
		
		printf "LIST [ ID: '0x%02x' ] in (%s)\n",$QuestionId, join ",", @ValueList;
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_OR_OP})				{	# 0x16
		printf "OR expression\n";
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_NOT_OP})				{	# 0x17
		printf "NOT expression \n";
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_TIME_OP})				{# 0x1b
		my $Prompt = unpack("S2",substr($op{'payload'},0,2));
		my $Help = unpack("S2",substr($op{'payload'},2,2));
		my $QuestionId = unpack("S2",substr($op{'payload'},4,2));
		my $VarStoreId = unpack("S2",substr($op{'payload'},8,2));
		
		#my $VarName = unpack("S2",substr($op{'payload'},8,1));
		#my $VarOffset = unpack("S2",substr($op{'payload'},9,1));
		#my $Flags = unpack("S2",substr($op{'payload'},9,1));
	
		printf "Time: '%s' [ QuestionId: '0x%02x', VarStore: '0x%02x', Help: '%s' ]\n", $STRINGS[$Prompt],$QuestionId,$VarStoreId,$STRINGS[$Help] ;		
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_DATE_OP})				{# 0x1A
		my $Prompt = unpack("S2",substr($op{'payload'},0,2));
		my $Help = unpack("S2",substr($op{'payload'},2,2));
		my $QuestionId = unpack("S2",substr($op{'payload'},4,2));
		my $VarStoreId = unpack("S2",substr($op{'payload'},8,2));
		
		#my $VarName = unpack("S2",substr($op{'payload'},8,1));
		#my $VarOffset = unpack("S2",substr($op{'payload'},9,1));
		#my $Flags = unpack("S2",substr($op{'payload'},9,1));
	
		printf "Date: '%s' [ QuestionId: '0x%02x', VarStore: '0x%02x', Help: '%s' ]\n", $STRINGS[$Prompt],$QuestionId,$VarStoreId,$STRINGS[$Help] ;	
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_NUMERIC_OP})			{# 0x07
		my $Prompt = unpack("S2",substr($op{'payload'},0,2));
		my $Help = unpack("S2",substr($op{'payload'},2,2));
		my $QuestionId = unpack("S2",substr($op{'payload'},4,2));
		my $VarStoreId = unpack("S2",substr($op{'payload'},8,2));
		#my $VarStoreInfo = unpack("C",substr($op{'payload'},10,1));
 
		my $Type = unpack("C",substr($op{'payload'},11,1));
		my $MinValue = unpack("C",substr($op{'payload'},12,1));
		my $MaxValue = unpack("C",substr($op{'payload'},13,1));
		my $Step = unpack("C",substr($op{'payload'},14,1));
 
		printf "Number question: Prompt: %s, Help: %s\n",($STRINGS[$Prompt], $STRINGS[$Help]) if $Prompt;;
		printf "%s \x{E2}\x{94}\x{94}- [ QuestionId: '0x%02x', VarStore: '0x%02x' , Type: '%02x', MinValue: '%d', MaxValue: '%d', Step: '%d' ]\n",($TabSpace,$QuestionId, $VarStoreId, $Type,$MinValue, $MaxValue, $Step) if $Prompt;;
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_REF_OP})				{# 0x0F
		my $Prompt = unpack("S2",substr($op{'payload'},0,2));
		my $Help = unpack("S2",substr($op{'payload'},2,2));
		my $QuestionId = unpack("S2",substr($op{'payload'},4,2));
		my $VarStoreId = unpack("S2",substr($op{'payload'},8,2));
		
		my $FormId = unpack("S2>*!",substr($op{'payload'},11,4));
		
		printf "Reference: '%s' [ FormID: '0x%04x', QuestionId: '0x%02x', VarStore: '0x%02x' ]\n", $STRINGS[$Prompt], $FormId, $QuestionId, $VarStoreId;
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_ACTION_OP})			{# 0x0C
		my $Prompt = unpack("S2",substr($op{'payload'},0,2));
		my $Help = unpack("S2",substr($op{'payload'},2,2));
		my $QuestionId = unpack("S2",substr($op{'payload'},4,2));
		my $VarStoreId = unpack("S2",substr($op{'payload'},8,2));
		#my $VarStoreInfo = unpack("C",substr($op{'payload'},8,1));
		
		printf "Action: '%-32.32sHelp: %s\n", ($STRINGS[$Prompt]."'", $STRINGS[$Help]);
		printf "%s \x{E2}\x{94}\x{94}- [ QuestionId: '0x%02x', VarStore: '0x%02x' ]\n", ($TabSpace,$QuestionId,$VarStoreId) if $STRINGS[$Prompt];
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_PASSWORD_OP})			{# 0x08
		my $Prompt = unpack("S2", substr($op{'payload'},0,2));
		my $Help    = unpack("S2", substr($op{'payload'},2,2));
		my $VarStoreId = unpack("S2", substr($op{'payload'},8,2));
		printf "Password: %-32.32s [ VarStore: '0x%02x', Help: '%s']\n", ($STRINGS[$Prompt], $VarStoreId, $STRINGS[$Help]);
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_ONE_OF_OP}) {			# 0x05
		my $Prompt = unpack("S2", substr($op{'payload'},0,2));
		my $Help    = unpack("S2", substr($op{'payload'},2,2));
		my $QuestionId = unpack("S2", substr($op{'payload'},4,2));
		my $VarStoreId = unpack("S2", substr($op{'payload'},8,2));
#		my $VarOffset    = unpack("S2", substr($op{'payload'},4,2));
		
		printf "Select option: '%-32.32s[ VarStore: '0x%02x', QuestionId: '0x%02x',   Help: '%s']\n", ($STRINGS[$Prompt]."'", $VarStoreId, $QuestionId, (defined $STRINGS[$Help] ? $STRINGS[$Help] : '' ));
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_ONE_OF_OPTION_OP}) {	# 0x09
		my $Option	= unpack("S2", substr($op{'payload'},0,2));
		my $Flags	= str2hex(substr($op{'payload'},2,1));
		my $Type	= unpack("C", substr($op{'payload'},3,1));
		my $Value	= unpack("C*", substr($op{'payload'},4,8));
 
#			oid, value, flags, key = struct.unpack("<HHBH", self.payload)
#			print ts+"Option '%s' = 0x%x Flags 0x%x Key 0x%x"%(s[oid], value, flags, key)
		
		printf "  Option: '%-37.37s[ Value: '%s'   Default: '%-6s    Type: '%-6.6s ]\n", ($STRINGS[$Option]."'", $Value, ($Flags eq '10' ? 'true' : 'false')."'", $TYPES{$Type}."'");
 
	}
	elsif ($op{'opcode'} == $EFI{EFI_IFR_VARSTORE_EFI_OP}) {	# 0x1A
		printf "  EFI_IFR_VARSTORE_EFI_OP\n";
 
	}
	else {
		printf STDERR "--> UNKNOWN OPCODE: %02X, length: %d\n", $op{'opcode'}, $op{'length'};
		exit 1;
	}
}
 
sub SPECIFICATION_LOAD
{
	$EFI{EFI_IFR_FORM_OP}                 = 0x01;
	$EFI{EFI_IFR_SUBTITLE_OP}             = 0x02;
	$EFI{EFI_IFR_TEXT_OP}                 = 0x03;
	$EFI{EFI_IFR_IMAGE_OP}                = 0x04;
	$EFI{EFI_IFR_ONE_OF_OP}               = 0x05;
	$EFI{EFI_IFR_CHECKBOX_OP}             = 0x06;
	$EFI{EFI_IFR_NUMERIC_OP}              = 0x07;
	$EFI{EFI_IFR_PASSWORD_OP}             = 0x08;
	$EFI{EFI_IFR_ONE_OF_OPTION_OP}        = 0x09;
	$EFI{EFI_IFR_SUPPRESS_IF_OP}          = 0x0A;
	$EFI{EFI_IFR_LOCKED_OP}               = 0x0B;
	$EFI{EFI_IFR_ACTION_OP}               = 0x0C;
	$EFI{EFI_IFR_RESET_BUTTON_OP}         = 0x0D;
	$EFI{EFI_IFR_FORM_SET_OP}             = 0x0E;
	$EFI{EFI_IFR_REF_OP}                  = 0x0F;
	$EFI{EFI_IFR_NO_SUBMIT_IF_OP}         = 0x10;
	$EFI{EFI_IFR_INCONSISTENT_IF_OP}      = 0x11;
	$EFI{EFI_IFR_EQ_ID_VAL_OP}            = 0x12;
	$EFI{EFI_IFR_EQ_ID_ID_OP}             = 0x13;
	$EFI{EFI_IFR_EQ_ID_LIST_OP}           = 0x14;
	$EFI{EFI_IFR_AND_OP}                  = 0x15;
	$EFI{EFI_IFR_OR_OP}                   = 0x16;
	$EFI{EFI_IFR_NOT_OP}                  = 0x17;
	$EFI{EFI_IFR_RULE_OP}                 = 0x18;
	$EFI{EFI_IFR_GRAY_OUT_IF_OP}          = 0x19;
	$EFI{EFI_IFR_DATE_OP}                 = 0x1A;
	$EFI{EFI_IFR_TIME_OP}                 = 0x1B;
	$EFI{EFI_IFR_STRING_OP}               = 0x1C;
	$EFI{EFI_IFR_REFRESH_OP}              = 0x1D;
	$EFI{EFI_IFR_DISABLE_IF_OP}           = 0x1E;
	$EFI{EFI_IFR_ANIMATION_OP}            = 0x1F;
	$EFI{EFI_IFR_TO_LOWER_OP}             = 0x20;
	$EFI{EFI_IFR_TO_UPPER_OP}             = 0x21;
	$EFI{EFI_IFR_MAP_OP}                  = 0x22;
	$EFI{EFI_IFR_ORDERED_LIST_OP}         = 0x23;
	$EFI{EFI_IFR_VARSTORE_OP}             = 0x24;
	$EFI{EFI_IFR_VARSTORE_NAME_VALUE_OP}  = 0x25;
	$EFI{EFI_IFR_VARSTORE_EFI_OP}         = 0x26;
	$EFI{EFI_IFR_VARSTORE_DEVICE_OP}      = 0x27;
	$EFI{EFI_IFR_VERSION_OP}              = 0x28;
	$EFI{EFI_IFR_END_OP}                  = 0x29;
	$EFI{EFI_IFR_MATCH_OP}                = 0x2A;
	$EFI{EFI_IFR_GET_OP}                  = 0x2B;
	$EFI{EFI_IFR_SET_OP}                  = 0x2C;
	$EFI{EFI_IFR_READ_OP}                 = 0x2D;
	$EFI{EFI_IFR_WRITE_OP}                = 0x2E;
	$EFI{EFI_IFR_EQUAL_OP}                = 0x2F;
	$EFI{EFI_IFR_NOT_EQUAL_OP}            = 0x30;
	$EFI{EFI_IFR_GREATER_THAN_OP}         = 0x31;
	$EFI{EFI_IFR_GREATER_EQUAL_OP}        = 0x32;
	$EFI{EFI_IFR_LESS_THAN_OP}            = 0x33;
	$EFI{EFI_IFR_LESS_EQUAL_OP}           = 0x34;
	$EFI{EFI_IFR_BITWISE_AND_OP}          = 0x35;
	$EFI{EFI_IFR_BITWISE_OR_OP}           = 0x36;
	$EFI{EFI_IFR_BITWISE_NOT_OP}          = 0x37;
	$EFI{EFI_IFR_SHIFT_LEFT_OP}           = 0x38;
	$EFI{EFI_IFR_SHIFT_RIGHT_OP}          = 0x39;
	$EFI{EFI_IFR_ADD_OP}                  = 0x3A;
	$EFI{EFI_IFR_SUBTRACT_OP}             = 0x3B;
	$EFI{EFI_IFR_MULTIPLY_OP}             = 0x3C;
	$EFI{EFI_IFR_DIVIDE_OP}               = 0x3D;
	$EFI{EFI_IFR_MODULO_OP}               = 0x3E;
	$EFI{EFI_IFR_RULE_REF_OP}             = 0x3F;
	$EFI{EFI_IFR_QUESTION_REF1_OP}        = 0x40;
	$EFI{EFI_IFR_QUESTION_REF2_OP}        = 0x41;
	$EFI{EFI_IFR_UINT8_OP}                = 0x42;
	$EFI{EFI_IFR_UINT16_OP}               = 0x43;
	$EFI{EFI_IFR_UINT32_OP}               = 0x44;
	$EFI{EFI_IFR_UINT64_OP}               = 0x45;
	$EFI{EFI_IFR_TRUE_OP}                 = 0x46;
	$EFI{EFI_IFR_FALSE_OP}                = 0x47;
	$EFI{EFI_IFR_TO_UINT_OP}              = 0x48;
	$EFI{EFI_IFR_TO_STRING_OP}            = 0x49;
	$EFI{EFI_IFR_TO_BOOLEAN_OP}           = 0x4A;
	$EFI{EFI_IFR_MID_OP}                  = 0x4B;
	$EFI{EFI_IFR_FIND_OP}                 = 0x4C;
	$EFI{EFI_IFR_TOKEN_OP}                = 0x4D;
	$EFI{EFI_IFR_STRING_REF1_OP}          = 0x4E;
	$EFI{EFI_IFR_STRING_REF2_OP}          = 0x4F;
	$EFI{EFI_IFR_CONDITIONAL_OP}          = 0x50;
	$EFI{EFI_IFR_QUESTION_REF3_OP}        = 0x51;
	$EFI{EFI_IFR_ZERO_OP}                 = 0x52;
	$EFI{EFI_IFR_ONE_OP}                  = 0x53;
	$EFI{EFI_IFR_ONES_OP}                 = 0x54;
	$EFI{EFI_IFR_UNDEFINED_OP}            = 0x55;
	$EFI{EFI_IFR_LENGTH_OP}               = 0x56;
	$EFI{EFI_IFR_DUP_OP}                  = 0x57;
	$EFI{EFI_IFR_THIS_OP}                 = 0x58;
	$EFI{EFI_IFR_SPAN_OP}                 = 0x59;
	$EFI{EFI_IFR_VALUE_OP}                = 0x5A;
	$EFI{EFI_IFR_DEFAULT_OP}              = 0x5B;
	$EFI{EFI_IFR_DEFAULTSTORE_OP}         = 0x5C;
	$EFI{EFI_IFR_FORM_MAP_OP}             = 0x5D;
	$EFI{EFI_IFR_CATENATE_OP}             = 0x5E;
	$EFI{EFI_IFR_GUID_OP}                 = 0x5F;
	$EFI{EFI_IFR_SECURITY_OP}             = 0x60;
 
	%EFI_HII_PACKAGE_TYPE = 
	(
		0x00	=> { name => 'EFI_HII_PACKAGE_TYPE_ALL'				, text => 'Pseudo-package type' },
		0x01	=> { name => 'EFI_HII_PACKAGE_TYPE_GUID'			, text => 'Package type where the format of the data is specified using a GUID immediately following the package header' },	
		0x02	=> { name => 'EFI_HII_PACKAGE_FORMS'				, text => 'Forms package' },
		0x04	=> { name => 'EFI_HII_PACKAGE_STRINGS'				, text => 'Strings package' },
		0x05	=> { name => 'EFI_HII_PACKAGE_FONTS'				, text => 'Fonts package' },
		0x06	=> { name => 'EFI_HII_PACKAGE_IMAGES'				, text => 'Images package' },
		0x07	=> { name => 'EFI_HII_PACKAGE_SIMPLE_FONTS'			, text => 'Simplified (8x19, 16x19) Fonts package' },
		0x08	=> { name => 'EFI_HII_PACKAGE_DEVICE_PATH'			, text => 'Binary-encoded device path' },
		0x09	=> { name => 'EFI_HII_PACKAGE_KEYBOARD_LAYOUT'		, text => 'Used to mark the end of a package list' },
		0x0A	=> { name => 'EFI_HII_PACKAGE_ANIMATIONS'			, text => 'Animations package' },
		0xDF	=> { name => 'EFI_HII_PACKAGE_END'					, text => 'Package types reserved for use by platform firmware implementations' },
		0xE0	=> { name => 'EFI_HII_PACKAGE_TYPE_SYSTEM_BEGIN'	, text => 'Package types reserved for use by platform firmware implementations' },
	);
 
%TYPES = 
(
	0x00 => 'int8',
    0x01 => 'int16',
    0x02 => 'int32',
    0x03 => 'int64',
    0x04 => 'bool',
    0x05 => 'time',
    0x06 => 'date',
    0x07 => 'string',
	0x08 => 'other',
);
 
}
 
