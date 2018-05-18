#!/usr/bin/perl
# takes a reference set of slowcontrols and manipulates bits of them
# to copy to Frankenstein, use command:
# scp -r output/Module* calice@192.168.1.11:C:\\Users\\calice\\Desktop\\cosmics_slowcontrols\\

use strict;
use warnings;
use File::Basename;
use File::Path qw/make_path/;

#my $baseSrcDir        = "/home/kvas/pool/SPIROC2E-SC/reference";
#my $baseSrcDir = "/home/calice/TB2018/mount_frankenstein/C/Users/calice/Desktop/cosmics_slowcontrols";    #source directory with module directories. no "/" at the end!
my $baseSrcDir = "./reference";
my $baseDstDir = "./output_AT_PP";       #output destination directories
my $dirNames   = "Module";         #module directory name (without number)

#my $srcSuffix  = "AT";
my $srcSuffix = "AT";
my $dstSuffix = "AT_AG350_TR260_LG1200_PP";

#my $selection_modules = "1";
my $selection_modules = "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40";
my $selection_slabs   = "2,3";

#my $selection_asics = "01,02";
my $selection_asics = "01,02,03,04,05,06,07,08";
my $overwriting     = 0;                           #do not modify from 0, otherwise will overwrite without single question

#following loop iterates over ASIC files
foreach my $file ( &getSelectionFilenames( $selection_modules, $selection_slabs, $selection_asics ) ) {    #loop through all ASIC files
    my @spiroc_sc = &load_sc($file);   #loads the SC bitstream
    print $file, " -> ", &getOutFilename($file), "\n";    #print source and output filenames with paths

    # -- place of asic-wise modifications --
    &setGainThr(\@spiroc_sc,350);
    &setGlobalTrigThr(\@spiroc_sc,260);
    #&setSwitchTdc(\@spiroc_sc,1); #switches off the TDC for _IC runs
    &setHGSlowShaperPPDisable(\@spiroc_sc,1); #disables powerpulsing for HG preamp

    for my $ch ( 0 .. 35 ) {
        # -- place of channel-wise modifications --
	&setLGPreamp(\@spiroc_sc,$ch,48); #48 is 1200fF
        #print &getDiscrChanMask( \@spiroc_sc, $ch );
        #print "Idac ch", $ch, "=", &getIdac( \@spiroc_sc, $ch ), " enabled=", &getIdacEnabled( \@spiroc_sc, $ch ), "\n ";
        #setHGPreamp( \@spiroc_sc, $ch, 23 );
        #setLGPreamp( \@spiroc_sc, $ch, 23 );
        #setPreampDisabled( \@spiroc_sc, $ch, 0 );      
    }
    &write_sc( &getOutFilename($file), @spiroc_sc ); # write the SC to the file (will ask to overwrite);
}

# --internal functions --

sub getSelectionFilenames {
    my ( $selection_modules, $selection_slabs, $selection_asics ) = @_;
    my @scfiles = ();                                                   #list of filetered filenames
    my @list_dirs = grep ( -d && /$dirNames\d+$/, glob "$baseSrcDir/*" );
    foreach my $dir (@list_dirs) { # for each module directory
	#next unless $dir =~ /$dirNames\d+$/;
        ( my $moduleNo ) = $dir =~ /\D(\d+)$/;
        grep( /^$moduleNo$/, split( /,/, $selection_modules ) ) || next;
        ( my $suffix_dir ) = ( grep( -d && /\/$srcSuffix$/, glob "$dir/*" ) ); #only specified suffix directory (i.e. /AT)
	if (! defined $suffix_dir) { next; } #do not proceed further if directory with suffix not found
	#print $suffix_dir ,"\n";
        my @slab_dirs = grep ( -d && /\/slab\d$/, glob "$suffix_dir/*" );
        foreach my $slab_dir (@slab_dirs) {# for each slab subdirectory
            ( my $slabNo ) = $slab_dir =~ /slab(\d)$/;
            grep( /^$slabNo$/, split( /,/, $selection_slabs ) ) || next;
            my @asic_files = grep ( -T && /SC_SP2b_ASIC\d+.txt/, glob "$slab_dir/*" );
            foreach my $asic_file (@asic_files) {#for each ASIC file
		#print "#found: ",$asic_file,"\n";
                ( my $asicIndex ) = $asic_file =~ /ASIC(\d+).txt/;
                grep( /^$asicIndex$/, split( /,/, $selection_asics ) ) || next;
                push( @scfiles, $asic_file );
            }
        }
    }
    return @scfiles;
}

sub load_sc {
    my $filename  = $_[0];
    my @spiroc_sc = ();      #list of bits in SC
    local $/ = undef;        # to ignore newlines and read the whole file to single variable
    open( my $FILE, $filename );
    my $content  = <$FILE>;
    my @lines    = split /\r\n|\n|\r/, $content;
    my $bitindex = 0;
    foreach my $line (@lines) {
        $line =~ /^\d+/ || next;

        # print $line, ",";
        for my $i ( 0 .. 7 ) {

            #	    if ( $line & ( 1 << ( 7 - $i ) ) ) {
            if ( $line & ( 1 << ($i) ) ) {
                $spiroc_sc[ $bitindex++ ] = 1;
            }
            else {
                $spiroc_sc[ $bitindex++ ] = 0;
            }
        }
    }

    #    print "\n";
    @spiroc_sc = reverse @spiroc_sc[ 0 .. ( $#spiroc_sc - 7 ) ];

    #foreach (@spiroc_sc) { print; }
    #    print "\n";
    return @spiroc_sc;
}

sub write_sc {
    my ( $filename, @spiroc_sc ) = @_;
    if (   ( -e $filename )
        && ( !$overwriting )
        && ( !&prompt("Overwrite existing file?") ) )
    {
        print "file exists and not specified to overwrite. Not doing anything\n";
        return;
    }
    @spiroc_sc = reverse( "0", "0", "0", "0", "0", "0", "0", @spiroc_sc );
    my $dir = dirname($filename);
    make_path($dir);
    open my $fh, '>', $filename
      or die "could not open file '" . $filename . "'for writing: $!\n";
    my $endline = "\r";
    print $fh "SPIROC2b-dummy  Version A", $endline;
    my $bitindex = 0;
    my $byte     = 0;

    foreach my $bit (@spiroc_sc) {
        if ( $bit eq "1" ) {
            $byte += 1 << ($bitindex);
        }
        if ( ( ++$bitindex ) == 8 ) {
            $bitindex = 0;
            print $fh $byte, $endline;
            $byte = 0;
        }
    }
    # print "\n";
}

sub prompt {
    my $question = $_[0];
    #    local $| = 1; # activate autoflush to immediately show the prompt
    print $question, " [Y/N/A] (yes/no/all):";
    chomp( my $answer = <STDIN> );
    if ( $answer =~ /^[yY]/ ) { return 1; }
    if ( $answer =~ /^[aA]/ ) { $overwriting = 1; return 1; }
    return 0;
}

sub getOutFilename {
    my ($srcFilename) = @_;
    my ( $moduleNo, $suffix, $slabNo, $asicNo ) = $srcFilename =~ /$dirNames(\d+)\/([^\/]+)\/slab(\d+)\/.+ASIC(\d+)\./;
    # print "module=",$moduleNo,"\n";
    # print "suffix=",$suffix,"\n";
    # print "slab=",$slabNo,"\n";
    # print "asic=",$asicNo+0,"\n";
    my $outfile = $baseDstDir . "/Module" . $moduleNo . "/" . $dstSuffix . "/slab" . $slabNo . "/SC_SP2b_ASIC" . $asicNo . ".txt";
    #    print $outfile,"\n";
    return $outfile;
}

sub getIntValue {
    my ( $sc_ref, $offset, $bits ) = @_;
    my $value = 0;
    for my $bin ( $offset .. ( $offset + $bits - 1 ) ) {
        if ( @$sc_ref[$bin] eq "1" ) {
            $value += ( 1 << ( $bin - $offset ) );
        }
    }
    return $value;
}

sub setIntValue {
    my ( $sc_ref, $offset, $bits, $value ) = @_;
    for my $bin ( $offset .. ( $offset + $bits - 1 ) ) {
        if ( $value & ( 1 << ( $bin - $offset ) ) ) {
            @$sc_ref[$bin] = "1";
        }
        else {
            @$sc_ref[$bin] = "0";
        }
    }
}

sub bitReorder {    #change from MSB to LSB and vice versa.
    my ( $value, $bits ) = @_;
    my $newValue = 0;
    for my $bit ( 0 .. ( $bits - 1 ) ) {
        if ( $value & ( 1 << $bit ) ) {
            $newValue |= 1 << ( $bits - $bit - 1 );
        }
    }
    return $newValue;
}

sub bitInvert {     #invert bits in n-bit number
    my ( $value, $bits ) = @_;
    return ( ~$value ) & ( ( 1 << $bits ) - 1 );
}

#params:SC
sub getChipID { return getIntValue( $_[0], 17, 8 ); }

#params:SC,chipid
sub setChipID { setIntValue( $_[0], 17, 8, $_[1] ); }

#params:SC,channel
sub getHGPreamp { return &bitReorder( &bitInvert( &getIntValue( $_[0], 366 + 15 * $_[1], 6 ), 6 ), 6 ); }

#params:SC,channel
sub getLGPreamp { return &bitReorder( &bitInvert( &getIntValue( $_[0], 366 + 15 * $_[1] + 6, 6 ), 6 ), 6 ); }

#params:SC,channel
sub getPreampDisabled { return &getIntValue( $_[0], 366 + 15 * $_[1] + 14, 1 ); }

#params:sc,channel,value
sub setHGPreamp { &setIntValue( $_[0], 366 + 15 * $_[1], 6, &bitReorder( &bitInvert( $_[2], 6 ), 6 ) ); }

#params:sc,channel,value
sub setLGPreamp { &setIntValue( $_[0], 366 + 15 * $_[1] + 6, 6, &bitReorder( &bitInvert( $_[2], 6 ), 6 ) ); }

#params:sc,channel,value
sub setPreampDisabled { &setIntValue( $_[0], 366 + 15 * $_[1] + 14, 1, $_[2] ); }

#param: SC
sub getGlobalTrigThr { return &bitReorder( &getIntValue( $_[0], 930, 10 ), 10 ); }

#param:SC, value
sub setGlobalTrigThr { &setIntValue( $_[0], 930, 10, &bitReorder( $_[1], 10 ) ); }

#param: SC
sub getGainThr { return &bitReorder( &getIntValue( $_[0], 940, 10 ), 10 ); }

#param:SC, value
sub setGainThr { &setIntValue( $_[0], 940, 10, &bitReorder( $_[1], 10 ) ); }

#Param: SC, ch
sub getIdac { return &bitReorder( &getIntValue( $_[0], 36 + 9 * $_[1], 8 ), 8 ); }

#Param: SC, ch
sub getIdacEnabled { return &getIntValue( $_[0], 36 + 9 * $_[1] + 8, 1 ); }

#param: SC, ch, value
sub setIdac { &setIntValue( $_[0], 36 + 9 * $_[1], 8, &bitReorder( $_[2], 8 ) ); }

#Param: SC
sub getHoldTrigger { return &bitReorder( &getIntValue( $_[0], 997, 8 ), 8 ); }

#param: SC, value
sub setHoldTrigger { &setIntValue( $_[0], 997, 8, &bitReorder( $_[1], 8 ) ); }

#Param: SC
sub getHoldValid { return &bitReorder( &getIntValue( $_[0], 1157, 6 ), 6 ); }

#param: SC, value
sub setHoldValid { &setIntValue( $_[0], 1157, 6, &bitReorder( $_[1], 6 ) ); }

#Param: SC
sub getHoldRst { return &bitReorder( &getIntValue( $_[0], 1164, 6 ), 6 ); }

#param: SC, value
sub setHoldRst { &setIntValue( $_[0], 1164, 6, &bitReorder( $_[1], 6 ) ); }

#param SC, ch, return: 0=normal operation, 1=masked
sub getDiscrChanMask { return &getIntValue( $_[0], 959 + $_[1], 1 ); }

#param SC, ch, value (0=normal operation, 1=masked)
sub setDiscrChanMask { &setIntValue( $_[0], 959 + $_[1], 1, $_[2] ); }

#param SC (0=TDC will be converted, 1=other gain will be converted)
sub getSwitchTdc { return &getIntValue( $_[0], 958 , 1 ); }

#param SC,value (0=TDC will be converted, 1=other gain will be converted)
sub setSwitchTdc {&setIntValue( $_[0], 958, 1,$_[1] ); }

#param: SC
sub getHGSlowShaperPPDisable {return &getIntValue( $_[0], 911 , 1 );}

#param SC,value (0= High gain preamplifier will enter powerpulsing, 1=powerpulsing disabled)
sub setHGSlowShaperPPDisable{&setIntValue( $_[0], 911, 1,$_[1] );}
    
#Labview Register Name	bits	Register description	Subadd
#GC: sw_ramp_on_adc	1		0
#NC	1	NC	1
#EC : Trig Ext (OR36)	1	 Enable external trig_ext (OR36)	2
#EC : Flag TDC Ext	1	 Enable external flag_tdc_ext signal	3
#EC : Start Ramp ADC Ext	1	 Enable external startb_ramp_adc signal	4
#EC : Start Ramp TDC Ext	1	 Enable external start_ramp_tdc signal	5
#GC : ADC Gray (12 bits)	12	 ADC Gray counter resolution register (from LSB to MSB)	17
#GC : Chip ID (8 bits)	8	 Chip ID (from LSB to MSB)	25
#EN_Probe OTAq	1	 Enable Probe OTA	26
#EN_Analog OTAq	1	 Enable Analogue Output OTA	27
#PP: Analogue Output OTAq	1	 Disable Analogue Output OTA power pulsing mode (force ON)	28
#NC	1	NC	29
#EN_OR36	1	 Enable digital OR36 output [active low]	30
#GC: ADC Ramp Slope	2	 ADC ramp slope (ramp slope 12-bit [00], 10-bit [10] or 8-bit [11])	32
#PP: ADC Ramp Current Source	1	 Enable adc ramp current source power pulsing	33
#PP: ADC Ramp Integrator	1	 Enable adc ramp integrator power pulsing	34
#EN_input_dac	1	 Enable 36 input 8-bit DACs	35
#GC : 8-bit DAC reference	1	 8-bit input DAC Voltage Reference (1 = internal 4,5V , 0 = internal 2,5V)	36
#ID : Input 8-bit DAC	324	 Input 8-bit DAC Data from channel 0 to 36 – (DAC7…DAC0 + DAC ON)	360
#GC : LG PA bias	1	 Low Gain PreAmp bias ( 1 = weak bias, 0 = normal bias)	361
#PP: High Gain PreAmplifier	1	 Disable High Gain preamp power pulsing mode (force ON)	362
#EN_High_Gain_PA	1	 Enable High Gain preamp	363
#PP: Low Gain PreAmplifier	1	 Disable Low Gain preamp power pulsing mode (force ON)	364
#EN_Low_Gain_PA	1	 Enable Low Gain preamp	365
#GC : Fast Shaper on LG	1	 Select LG PA to send to Fast Shaper	366
#Channel 0 to 35 PA	540	 Ch0 to 35 PreAmp config (HG gain[5..0], LG gain [5..0], CtestHG, CtestLG, PA disabled)	906
#PP: Low Gain Slow Shaper	1	 Disable low gain slow shaper power pulsing mode (force ON)	907
# EN_Low_Gain_Slow Shaper	1	 Enable Low Gain Slow Shaper	908
#GC : Time Constant LG Shaper	3	 Low gain shaper time constant commands (2…0)  [active low]	911
#PP: High Gain Slow Shaper	1	 Disable high gain slow shaper power pulsing mode (force ON)	912
# EN_High_Gain_Slow Shaper	1	 Enable high gain Slow Shaper	913
#GC : Time Constant HG Shaper	3	 High gain shaper time constant commands (2…0)  [active low]	916
#PP:  Suiveur fast shaper	1	 Disable fast shaper power pulsing mode (force ON)	917
#EN_Fast Shaper	1	 Enable fast Shaper	918
#PP: Fast Shaper	1	 Disable fast shaper power pulsing mode (force ON)	919
#GC : backup SCA	1	 Enable backup SCA	920
#PP: SCA	1	 Enable SCA power pulsing	921
#GC: Temp sensor high current	1	Enable High current for temp sensor to drive the 36 ADC comparators	922
#PP: Temp	1	 Disable Temperature Sensor power pulsing mode (force ON)	923
#EN_Temp	1	 Enable Temperature Sensor	924
#PP: BandGap	1	 Disable BandGap power pulsing mode (force ON)	925
#EN_BandGap	1	 Enable BandGap	926
#EN_DAC1	1	 Enable DAC	927
#PP: DAC1	1	 Disable DAC power pulsing mode (force ON)	928
#EN_DAC2	1	 Enable DAC	929
#PP: DAC2	1	 Disable DAC power pulsing mode (force ON)	930
#GC : DAC 1 : Trigger	10	 10-bit DAC (MSB-LSB) discri_trigger_threshold	940
#GC : DAC 2 : Gain Sel.	10	 10-bit DAC (MSB-LSB) discri_gs_threshold	950
#GC : TDC Ramp Slope	1	 TDC ramp slope (fast = 0 or slow = 1)	951
#EN_TDC Ramp	1	 Enable TDC ramp	952
#PP: TDC Ramp	1	 Enable TDC ramp power pulsing	953
#PP: ADC Discri	1	 Enable ADC discri power pulsing	954
#PP: Gain Select Discri	1	 Enable gain selection discri power pulsing	955
#GC : Auto Gain	1	 Auto gain selection (active low)	956
#GC : Gain Select	1	 Forces the gain value when auto gain selection is OFF	957
#EC : ADC Ext Input	1	 External ADC signal input	958
#GC : Switch TDC On	1	 Switch for time signal charge signal readout / high gain and low gain charge	959
#DM : Discriminator Mask	36	 Allows to Mask Discriminator (channel 35 to 0)	995
#EN : Discri Delay Vref  + I source (Trigger)	1		996
#PP: Discri Delay Vref  + I source (Trigger)	1	 Enable reference voltage of discri delay + current source power pulsing	997
#GC : Delay (Trigger)	8	 Delay for the ”trigger” signals ( From MSB to LSB)	1005
#DD : Discri 4-bit DAC Threshold Adjust	144	 Discri 4-bit DAC – from LSB to MSB - from channel 35 to 0	1149
#PP: Trigger Discriminator	1	 Enable trigger discri power pulsing	1150
#PP: 4-bit DAC	1	 Enable 4 bit dac power pulsing	1151
#PP: Discri Delay (Trigger)	1	 Enable Delay (Trigger) discriminator power pulsing	1152
#NC	4		1156
#PP: Delay (ValidHold)	1	 Enable Delay cell power pulsing for the ”ValidHold” signal	1157
#GC : Delay (ValidHold)	6	 Delay for the ”ValidHold” signal ( From MSB to LSB)	1163
#PP: Delay (RstColumn)	1	 Enable Delay cell power pulsing for the ”RstColumn” signal	1164
#GC : Delay (RstColumn)	6	 Delay for the ”RstColumn” signal ( From MSB to LSB)	1170
#EN: LVDS receiver NoTrig	1	 Enable LVDS Receivers NoTrig	1171
#PP: LVDS receiver NoTrig	1	 Enable LVDS Receivers Power Pulsing NoTrig	1172
#EN: LVDS receiver ValEvt	1	 Enable LVDS Receivers ValEvt	1173
#PP: LVDS receiver ValEvt	1	 Enable LVDS Receivers Power Pulsing ValEvt	1174
#EN: LVDS receiver TriExt	1	 Enable LVDS Receivers TrigExt	1175
#PP: LVDS receiver TrigExt	1	 Enable LVDS Receivers Power Pulsing TrigExt	1176
#PP: 40MHz & 10MHz Clock LVDS	1	 Enable LVDS Receivers Power Pulsing	1177
#GC : POD bypass	1	 Bypass POD command	1178
#EC : End_ReadOut	1	 Enable End_ReadOut1 ('1') or End_ReadOut2 ('0')	1179
#EC : Start_ReadOut	1	 Select Start_ReadOut1 ('1') or Start_ReadOut2 ('0')	1180
#EC : ChipSat	1	 Enable Opened collector ChipSat signal	1181
#EC : TransmitOn2	1	 Enable Opened collector TransmitOn2 signal	1182
#EC : TransmitOn1	1	 Enable Opened collector TransmitOn1 signal	1183
#EC : Dout2	1	 Enable Opened collector Dout2 signal	1184
#EC : Dout1	1	 Enable Opened collector Dout1 signal	1185
#Total	1186

