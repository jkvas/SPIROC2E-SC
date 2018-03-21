#use warnings
$baseSrcDir = "/home/kvas/ahcal/slowcontrols/reference";

my @list_dirs = grep { -d } glob "$baseSrcDir/*";

foreach (@list_dirs) {
	print $_. "\n";
}
