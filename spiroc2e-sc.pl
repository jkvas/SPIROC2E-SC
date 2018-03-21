#use warnings
my $baseSrcDir = "./reference";
my $dirNames = "Module";
my $suffix = "AT";
my $selection_modules="1,3,4,40";
my $selection_slabs="2,3";
my $selection_asics="01,02,03,04,04,05,06,07,08";

my @list_dirs = grep (-d && /$dirNames/, glob "$baseSrcDir/*");
my @module_dirs;
my @scfiles = ();

 MODULES:
    foreach $dir (@list_dirs) {
	($moduleNo) = $dir=~ /\D(\d+)$/;
	grep( /^$moduleNo$/, split(/,/,$selection_modules) ) || next MODULES;
	# print $dir."\t".$moduleNo."\n";
	#@suffix_dirs = grep(-d && /\/$suffix$/, glob "$dir/*");
	($suffix_dir) = (grep(-d && /\/$suffix$/, glob "$dir/*"));
	# print $suffix_dir,"\n";
	@slab_dirs = grep (-d && /\/slab\d$/, glob "$suffix_dir/*");
      SLABS:
	foreach $slab_dir (@slab_dirs){
	    ($slabNo)= $slab_dir =~ /slab(\d)$/;
	    grep( /^$slabNo$/, split(/,/,$selection_slabs) ) || next SLABS;
	    # print $slab_dir,"\t",$slabNo."\n"; 
	    @asic_files = grep (-T && /SC_SP2b_ASIC\d+.txt/, glob "$slab_dir/*");
	  ASICS:
	    foreach $asic_file (@asic_files){
		$asicIndex= ($asic_file =~ /ASIC(\d+).txt/)[0];
		grep( /^$asicIndex$/, split(/,/,$selection_asics) ) || next ASICS;
		# print $asic_file, "\t", $asicIndex, "\n";
		push(@scfiles,$asic_file);
	    }
	}
}

foreach $file (@scfiles){
    print $file, "\n";
}
