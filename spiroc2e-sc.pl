use strict;
use warnings;

my $baseSrcDir        = "/home/kvas/pool/SPIROC2E-SC/reference";
my $dirNames          = "Module";
my $suffix            = "AT";
my $selection_modules = "18";
my $selection_slabs   = "2,3";

#my $selection_asics   = "01,02,03,04,04,05,06,07,08";
my $selection_asics = "01,02";

my @list_dirs = grep ( -d && /$dirNames/, glob "$baseSrcDir/*" );
my @module_dirs;
my @scfiles = ();
my $dir;
my $moduleNo;
my @slab_dirs;
my $suffix_dir;
my $slabNo;
my @asic_files;
my $asic_file;
my $asicIndex;
MODULES:

foreach $dir (@list_dirs) {
	($moduleNo) = $dir =~ /\D(\d+)$/;
	grep( /^$moduleNo$/, split( /,/, $selection_modules ) ) || next MODULES;
	($suffix_dir) = ( grep( -d && /\/$suffix$/, glob "$dir/*" ) );
	@slab_dirs = grep ( -d && /\/slab\d$/, glob "$suffix_dir/*" );
  SLABS:
	foreach my $slab_dir (@slab_dirs) {
		($slabNo) = $slab_dir =~ /slab(\d)$/;
		grep( /^$slabNo$/, split( /,/, $selection_slabs ) ) || next SLABS;
		@asic_files = grep ( -T && /SC_SP2b_ASIC\d+.txt/, glob "$slab_dir/*" );
	  ASICS:
		foreach $asic_file (@asic_files) {
			$asicIndex = ( $asic_file =~ /ASIC(\d+).txt/ )[0];
			grep( /^$asicIndex$/, split( /,/, $selection_asics ) )
			  || next ASICS;
			push( @scfiles, $asic_file );
		}
	}
}

foreach my $file (@scfiles) {
	load_sc($file);
}

sub load_sc {
	my $filename = $_[0];
	print "#", $_[0], "\n";
	my @spiroc_sc = ();
	local $/ = undef;
	open( my $FILE, $filename );
	my $content = <$FILE>;
	my @lines = split /\r\n|\n|\r/, $content;
	foreach my $line (@lines) {
		print $line, "\t(";
		for my $i ( 0 .. 7 ) {
			if ( $line & ( 1 << ( 7 - $i ) ) ) {
				print "1";
			}
			else {
				print "0";
			}
		}
		print "),\n";
	}

	#	print "#", $_[0], "\n";
	return;
}

