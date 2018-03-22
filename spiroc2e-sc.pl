#use warnings
my $baseSrcDir        = "/home/kvas/pool/SPIROC2E-SC/reference";
my $dirNames          = "Module";
my $suffix            = "AT";
my $selection_modules = "1";
my $selection_slabs   = "2";

#my $selection_asics   = "01,02,03,04,04,05,06,07,08";
my $selection_asics = "08";

my @list_dirs = grep ( -d && /$dirNames/, glob "$baseSrcDir/*" );
my @module_dirs;
my @scfiles = ();
MODULES:
foreach $dir (@list_dirs) {
	($moduleNo) = $dir =~ /\D(\d+)$/;
	grep( /^$moduleNo$/, split( /,/, $selection_modules ) ) || next MODULES;
	($suffix_dir) = ( grep( -d && /\/$suffix$/, glob "$dir/*" ) );
	@slab_dirs = grep ( -d && /\/slab\d$/, glob "$suffix_dir/*" );
  SLABS:
	foreach $slab_dir (@slab_dirs) {
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

foreach $file (@scfiles) {
	load_sc($file);
}

sub load_sc {
	print $_[0], "\n";
	return;
}
