## Foreword

This script would not have been possible without the following people to name a few:
 - ZFEbHVUE, main coder and tester
 - Rion
 - myzar's Nvidia knowledge
 - jfroco's work to output Batocera on a CRTs.
 - rtissera's knowledge, enthusiasm and willingness to add 15 KHz patches.
 - Calamity for his knowledge, drivers, tools and GroovyMame.
 - Substring's work on GroovyArcade, SDL, KMS etcetera.
 - D0023R Doozer's continued work at adding 15 KHz support to the Linux kernel.
 - dmanlcf's work on keeping up to date for the 15khz patches for Batocera.

### Contributors 
 - Sirmagb  (Thx for your CRT.sh geomtry tool idea)    
 - yavimaya (Thx for your code contribution)

### Testers 
 - GecKoTDF
 - Sirmagb

### Special Thanks
- krahsdevil (Emulation Station assets) 

## :video_game::penguin: Build-CRT-15KHz-Batocera-V35 :video_game::penguin:
Build-CRT-15KHz-Batocera V32 to V35 and 36-dev-2022/10/28

First public release

This bash script will help you setup Batocera on a Crt in 15-25-31kHz

It comes pre-configured with the 7 most common Monitor Profiles generated with Switchres.

These pre-configured Monitor Profiles have 30+ resolutions added that should only be used with

    Standalone Emulators
    Native Linux Games
    Non libretro Ports
    Wine, Flatpak & Steam
    For GroovyMame and Retroarch use video mode set to auto.

Monitor Profile info

    generic_15 - Good all around profile for generic Crt's with a range between - 15625-15750 kHz
    arcade_15 - Works well on normal consumer sets and has a wider range between - 15625-16200 kHz
    arcade_15ex - Same as arcade_15 with a slightly higher range between - 15625-16500 kHz
    arcade_15_25 - 15/25kHz Dual-sync arcade monitor - 15625-16200/24960-24960 kHz
    arcade_15_25_31 - 15.7/25.0/31.5 kHz - Tri-sync arcade monitor - 15625-16200/24960-24960/31400-31500 Khz
    ntsc - Consumer sets only capable of displaying 60Hz/525 - 15734.26-15734.26 Khz
    pal - Consumer sets only capable of displaying 50Hz/625 - 15625.00-15625.00 Khz

AMD Cards are preferred.

    Anything up to R9 380X will work. R5-R7-R9 Cards are highly recommended.

Intel have beentested and works somewhat.
    
    Tested on Optilex 790 and 7010
    It works with good on DisplayPort and somewhat on VGA (dotclock_min 25.0).

Nvidia Cards that are supported right now.

    It works for Kelper / Maxwell / Pascal with Nvidia driver (best performances) and Nouveau
    Tested on :
    8400GS        DVI-I / HDMI / VGA     Only Nouveau with dotclock_min 0 
    Quadro K600   DVI-I             Nvidia driver : dotclock_min 25.0  (Good performances)     Nouveau : dotclock_min 0.0 (not so good perfomrance)
    GTX 980       DVI-I / HMDI      DVI-I : dotclock_min 0.0        HDMI : dotclock_min 25.0   Nouveau :
    GTX 1050ti    HDMI              dotclock_min 25.0 (very good performances)   
    
    Display port (DP) works for all cards but it is only for Super-resolution 240p (no interlace here).
    Turing works poorly only in 240p (tested on GTX 1650 HDMI/DP).
    
    Conclusion with Nvidia cards, we recommand to use Maxwell 2.0 (Nvidia driver) Which has full support for 15KHz with DVI-I 
               and and with very good performance for GTX 970/980/980ti.
  
