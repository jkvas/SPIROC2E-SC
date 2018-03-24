#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use File::Path qw/make_path/;

#my $baseSrcDir        = "/home/kvas/pool/SPIROC2E-SC/reference";
my $baseSrcDir        = "./reference";
my $baseDstDir        = "./output";
my $dirNames          = "Module";
my $srcSuffix            = "AT";
my $dstSuffix            = "AT";
my $selection_modules = "1";
#my $selection_modules = "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40";
my $selection_slabs   = "2,3";
my $selection_asics   = "01";
#my $selection_asics   = "01,02,03,04,04,05,06,07,08";
my $overwriting = 0;

#my $selection_asics = "01,02";

foreach my $file (&getSelectionFilenames()) {#loop through all ASIC files
    my @spiroc_sc = &load_sc($file);#load the slowcontrol bit array
    print $file," -> ", &getOutFilename($file),"\n";
#    &setIntValue(\@spiroc_sc,17,8,&getIntValue(\@spiroc_sc,17,8)-1);
    &setChipID(\@spiroc_sc,&getChipID(\@spiroc_sc)-1);
    &write_sc(&getOutFilename($file),@spiroc_sc);
    for my $ch (0..35){
	setHGPreamp(\@spiroc_sc,$ch,23);
	setLGPreamp(\@spiroc_sc,$ch,23);
	setPreampDisabled(\@spiroc_sc,$ch,0);
	print "ch",$ch,"=";
	print sprintf("%.6b",&getHGPreamp(\@spiroc_sc,$ch))," ";
	print sprintf("%.6b",&getLGPreamp(\@spiroc_sc,$ch))," ";
	print &getIntValue(\@spiroc_sc,366+15*$ch+12,1)," ";
	print &getIntValue(\@spiroc_sc,366+15*$ch+13,1)," ";
	print &getIntValue(\@spiroc_sc,366+15*$ch+14,1),"\n";
    }
    #print &getIntValue(\@spiroc_sc,17,8),"\t";
    #print &getChipID(\@spiroc_sc),"\t";
    #print "\n";
}

sub getSelectionFilenames{
    my @scfiles = (); #list of filetered filenames
    my @list_dirs = grep ( -d && /$dirNames/, glob "$baseSrcDir/*" );
    foreach my $dir (@list_dirs) {
	(my $moduleNo) = $dir =~ /\D(\d+)$/;
	grep( /^$moduleNo$/, split( /,/, $selection_modules ) ) || next ;
	(my $suffix_dir) = ( grep( -d && /\/$srcSuffix$/, glob "$dir/*" ) );
	my @slab_dirs = grep ( -d && /\/slab\d$/, glob "$suffix_dir/*" );
	foreach my $slab_dir (@slab_dirs) {
	    (my $slabNo) = $slab_dir =~ /slab(\d)$/;
	    grep( /^$slabNo$/, split( /,/, $selection_slabs ) ) || next;
	    my @asic_files = grep ( -T && /SC_SP2b_ASIC\d+.txt/, glob "$slab_dir/*" );
	    foreach my $asic_file (@asic_files) {
		(my $asicIndex) =  $asic_file =~ /ASIC(\d+).txt/ ;
		grep( /^$asicIndex$/, split( /,/, $selection_asics ) ) || next;
		push( @scfiles, $asic_file );
	    }
	}
    }
    return @scfiles;
}

sub load_sc {
    my $filename = $_[0];
    my @spiroc_sc=();#list of bits in SC
    local $/ = undef; # to ignore newlines and read the whole file to single variable
    open( my $FILE, $filename );
    my $content = <$FILE>;
    my @lines = split /\r\n|\n|\r/, $content;
    my $bitindex=0;
    foreach my $line (@lines) {
	$line =~ /^\d+/ || next;
	# print $line, ",";
	for my $i ( 0 .. 7 ) {
#	    if ( $line & ( 1 << ( 7 - $i ) ) ) {
	    if ( $line & ( 1 << ( $i ) ) ) {
		$spiroc_sc[$bitindex++] = 1;
	    }
	    else {
		$spiroc_sc[$bitindex++] = 0;
	    }
	}
    }
#    print "\n";
    @spiroc_sc = reverse @spiroc_sc[0..($#spiroc_sc - 7)];
    foreach (@spiroc_sc){print;};print "\n";
    return @spiroc_sc;
}

sub write_sc{
    my ($filename, @spiroc_sc) = @_;
    if ((-e $filename) && (! $overwriting) && (! &prompt("Overwrite existing file?"))) {
	print "file exists and not specified to overwrite. Not doing anything\n";return
    }
    @spiroc_sc=reverse ("0","0","0","0","0","0","0",@spiroc_sc);
    my $dir = dirname($filename);
    make_path($dir);
    open my $fh, '>', $filename or die "could not open file '".$filename."'for writing: $!\n";
    my $endline="\r";
    print $fh "SPIROC2b-dummy  Version A",$endline;
    my $bitindex=0;
    my $byte=0;
    foreach my $bit ( @spiroc_sc){
        if ($bit eq "1") {
	    $byte += 1<<($bitindex);
	}
	if ((++$bitindex) == 8) {
	    $bitindex=0;
	    print $fh $byte,$endline;
	    $byte=0;
	}
    }
    # print "\n";    
}

sub prompt{
    my $question=$_[0];
#    local $| = 1; # activate autoflush to immediately show the prompt
    print $question," [Y/N/A] (yes/no/all):";
    chomp(my $answer = <STDIN>);
    if ($answer =~ /^[yY]/) {return 1;}
    if ($answer =~ /^[aA]/) {$overwriting=1; return 1;}
    return 0;
}

sub getOutFilename {
    my ($srcFilename) = @_;
    my ($moduleNo,$suffix,$slabNo,$asicNo) = $srcFilename =~ /$dirNames(\d+)\/([^\/]+)\/slab(\d+)\/.+ASIC(\d+)\./;
    # print "module=",$moduleNo,"\n";
    # print "suffix=",$suffix,"\n";
    # print "slab=",$slabNo,"\n";
    # print "asic=",$asicNo+0,"\n";
    my $outfile=$baseDstDir."/Module".$moduleNo."/".$dstSuffix."/slab".$slabNo."/SC_SP2b_ASIC".$asicNo.".txt";
    #    print $outfile,"\n";
    return $outfile;
}

sub getIntValue{
    my ($sc_ref,$offset,$bits) = @_;
    my $value = 0;
    for my $bin ($offset .. ($offset + $bits - 1)){
	if (@$sc_ref[$bin] eq "1") {
	    $value += (1<< ($bin-$offset));
	}
    }
    return $value;
}

sub setIntValue{
    my ($sc_ref,$offset,$bits,$value)=@_;
    for my $bin ($offset .. ($offset + $bits - 1)){
	if ($value & (1<<($bin-$offset))) {
	    @$sc_ref[$bin] = "1";
	} else {
	    @$sc_ref[$bin] = "0";
	}
    }
}

sub bitReorder{ #change from MSB to LSB and vice versa.
    my ($value,$bits)=@_;
    my $newValue=0;
    for my $bit (0..($bits-1)){
	if ($value & (1<<$bit)) {
	    $newValue |= 1<<($bits-$bit-1);
	}
    }
    return $newValue;
}

sub bitInvert{
    my ($value,$bits)=@_;
    return (~$value) & ((1<<$bits)-1);
}

sub getChipID{ return getIntValue($_[0],17,8);}#params:SC
sub setChipID{ setIntValue($_[0],17,8,$_[1]);}#params:SC,chipid


sub getHGPreamp{return &bitReorder(&bitInvert(&getIntValue($_[0],366+15*$_[1],6),6),6);}#params:SC,channel
sub getLGPreamp{return &bitReorder(&bitInvert(&getIntValue($_[0],366+15*$_[1]+6,6),6),6);}#params:SC,channel
sub getPreampDisabled{return &getIntValue($_[0],366+15*$_[1]+14,1);};#params:SC,channel
sub setHGPreamp{setIntValue($_[0],366+15*$_[1],6, &bitReorder(&bitInvert($_[2],6),6));}#params:sc,channel,value
sub setLGPreamp{setIntValue($_[0],366+15*$_[1]+6,6, &bitReorder(&bitInvert($_[2],6),6));}#params:sc,channel,value
sub setPreampDisabled{setIntValue($_[0],366+15*$_[1]+14,1,$_[2]);}#params:sc,channel,value
