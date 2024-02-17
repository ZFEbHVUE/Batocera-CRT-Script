## Foreword

This script would not have been possible without the following people to name a few:
 - ZFEbHVUE, main coder and tester
 - Rion, 15KHz CRT Guru-Meditation
 - myzar's Nvidia knowledge
 - jfroco's work to output Batocera on a CRTs.
 - rtissera's knowledge, enthusiasm and willingness to add 15 KHz patches.
 - Calamity for his knowledge, drivers, tools and GroovyMame.
 - Substring's work on GroovyArcade, SDL, KMS etcetera.
 - D0023R Doozer's continued work at adding 15 KHz support to the Linux kernel.
 - dmanlcf's work on keeping up to date for the 15khz patches for Batocera.

### Contributors 
 - Sirmagb  (Thx for your CRT.sh modeline's geometry tool idea)    
 - Yavimaya (Thx for your code contribution)

### Testers 
 - GecKoTDF
 - Sirmagb

### Special Thanks
- krahsdevil (Emulation Station assets) 
 
## :video_game::penguin: Batocera-CRT-Script :video_game::penguin:

This bash script will help you setup Batocera on a Crt in 15-25-31kHz
 
 - Complete integration of the [Switchres](https://github.com/antonioginer/switchres/blob/master/README.md) tool (not the api) for switching modelines. (resolutions)
 - Detection of AMD APUs up to 5700 XT if used with the Cabledeconn DP2VGA listed on the [Wiki](https://wiki.batocera.org/batocera-and-crt#displayport_to_vga_dac) page.
 - Creation of custom EDID during setup for the monitor profile chosen.
 - It will read resolutions from videomodes.conf but switchres will handle the resolution switching not xrandr. 
 - You are free to add your own resolution by editing the file as you choose but keep in mind you need to test if it works for your monitor profile first. 
  - The CRT geometry script is not working as of now. This will be fixed in the final release. 
  - Nvidia needs more testing so the more reports we can get as issues on Github or Discord the better. Preferably both for easy tracking.
  - Known freezing issue with AMD R9 cards in Emulation Station. 
  Set Game Launch Transition to Instant
  Main Menu->User Interface Settings->Game Launch Transition-> Instant
  
  - We have avoided using 640x480i & 320x240p for boot as we need those resolution for the geometry tool.
Instead we have opted for 641x480i & 321x240p for boot. 
It is 1 pixel off and nothing the user will ever notice during boot.
Keep in mind 321x240 (320x240p) as a boot resolution is not officially supported since there are no Emulation Station Theme support as of now.

It comes pre-configured with all 28 Monitor Profiles Switchres supports.

These pre-configured Monitor Profiles have 50+ resolutions added that should only be used with

 - Standalone Emulators
 - Native Linux Games
 - Non libretro Ports
 - Wine, Flatpak & Steam
 - GroovyMame & Retroarch is preconfigured to use the switchres api.

## Monitor Profile info

 - Generic CRT standards 15 KHz - generic_15, ntsc, pal
 - Arcade fixed frequency 15 KHz - arcade_15, arcade_15ex
 - Arcade fixed frequency 25/31KHz - arcade_25, arcade_31
 - Arcade multisync 15/25/31 KHz - arcade_15_25, arcade_15_25_31
 - VESA GTF - vesa_480, vesa_600, vesa_768, vesa_1024
 - PC monitor 120 Hz - pc_31_120, pc_70_120
 - Hantarex - h9110, polo, pstar
 - Wells Gardner - k7000, k7131, d9200, d9400, d9800
 - Makvision - m2929
 - Wei-Ya - m3129
 - Nanao - ms2930, ms929
 - Rodotron - r666b 

AMD Cards are preferred.

    Anything up to R9 380X will work. R5-R7-R9 Cards are highly recommended.

Intel have been tested and works somewhat.
    
    Tested on Optilex 790 and 7010
    It works with good on DisplayPort and somewhat on VGA (dotclock_min 25.0).

Nvidia Cards that are supported right now.

    It works for Kelper / Maxwell / Pascal with Nvidia driver (best performances) and Nouveau
    Tested on :
    8400GS        DVI-I / HDMI / VGA     Only Nouveau with dotclock_min 0 
    Quadro K600   DVI-I             Nvidia driver : dotclock_min 25.0  (Good performance)      Nouveau : dotclock_min 0.0 (not so good perfomrance)
    GTX 980       DVI-I / HMDI      DVI-I : dotclock_min 0.0        HDMI : dotclock_min 25.0   Nouveau :
    GTX 1050ti    HDMI              dotclock_min 25.0 (very good performances)   
    
    Turing works poorly only in 240p (tested on GTX 1650 HDMI/DP).
    
    Conclusion with Nvidia cards, we recommand to use Maxwell 1.0-2.0 arechitecture (Nvidia driver) 
    Which has full support for 15KHz with DVI-I and and with very good performance for GTX 970/980/980ti.
  
