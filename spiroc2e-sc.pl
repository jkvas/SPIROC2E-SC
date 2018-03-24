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
my $selection_modules = "18";
my $selection_slabs   = "2,3";
my $overwriting = 1;

my $selection_asics   = "01,02,03,04,04,05,06,07,08";
#my $selection_asics = "01,02";

foreach my $file (&getSelectionFilenames()) {
    my @spiroc_sc = &load_sc($file);#the slowcontrol bit array
    &write_sc(&getOutFilename($file),@spiroc_sc);
    print $file,"->", &getOutFilename($file),"\n";
    print &getIntValue(\@spiroc_sc,17,8),"\t";
    &setIntValue(\@spiroc_sc,17,8,&getIntValue(\@spiroc_sc,17,8)-1);
    print &getChipID(\@spiroc_sc),"\t";
    print "\n";
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
		# print "1";
		$spiroc_sc[$bitindex++] = 1;
	    }
	    else {
		# print "0";
		$spiroc_sc[$bitindex++] = 0;
	    }
	}
    }
#    print "\n";
    @spiroc_sc = reverse @spiroc_sc[0..($#spiroc_sc - 7)];
#    foreach (@spiroc_sc){print;};print "\n";
    return @spiroc_sc;
}

sub write_sc{
    (my $filename, my @spiroc_sc) = @_;
    if ((-e $filename) && (! $overwriting)) {
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


sub getOutFilename {
    (my $srcFilename) = @_;
    (my $moduleNo, my $suffix, my $slabNo, my $asicNo) = $srcFilename =~ /$dirNames(\d+)\/([^\/]+)\/slab(\d+)\/.+ASIC(\d+)\./;
    # print "module=",$moduleNo,"\n";
    # print "suffix=",$suffix,"\n";
    # print "slab=",$slabNo,"\n";
    # print "asic=",$asicNo+0,"\n";
    my $outfile=$baseDstDir."/Module".$moduleNo."/".$dstSuffix."/slab".$slabNo."/SC_SP2b_ASIC".$asicNo.".txt";
    #    print $outfile,"\n";
    return $outfile;
}

sub getIntValue{
    my($sc_ref,$offset,$bits)=@_;
#    print "offset=",$offset,"\n";
#    print "size=",@$#sc_ref,"\n";
    my $value=0;
    for my $bin ($offset .. ($offset + $bits - 1)){
#	print "(",$bin,")";
	if (@$sc_ref[$bin] eq "1") {
	    $value += (1<< ($bin-$offset));
	}
    }
    return $value;
}

sub setIntValue{
    my($sc_ref,$offset,$bits,$value)=@_;
    for my $bin ($offset .. ($offset + $bits - 1)){
	#	print "(",$bin,")";
	if ($value & (1<<($bin-$offset))) {
	    @$sc_ref[$bin] = "1";
	} else {
	    @$sc_ref[$bin] = "0";
	}
    }
}

sub getChipID{ return getIntValue($_[0],17,8);}
