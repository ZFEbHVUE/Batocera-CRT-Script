# Build-CRT-15KHz-Batocera-V35
Build-CRT-15KHz-Batocera-V14

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

Anything up to R9 380X will work. R5-R7-R9 Cards are recommended.

Intel is tested and works somewhat.

  It works well with DisplayPort and somewhat on VGA

Nvidia Cards are supported right now.

   It works for Kelper / Maxwell / Pascal with Nvidia driver (best performances) and Nouveau
   
   Tested on : 
   
   8400GS        DVI-I /   VGA     Only Nouveau with dotclock_min 0
   Quadro K600   DVI-I             Nvidia driver : dotclock_min 25.0      Nouveau : dotclock_min 0.0   
   GTX 980       DVI-I / HMDI      DVI-I : dotclock_min 0.0        HDMI : dotclock_min 25.0  
   GTX 1050ti    HDMI              dotclock_min 25.0
   
   Dipslay port (DP) works for all cards but it is only for Super-resolution 240p (no interlace here).
   
   Turing works poorly only in 240p (tested on GTX 1650 HDMI/DP).
   
   Conclusion with Nvidia cards, we recommand to use Maxwell who it is full 15KHz.
  
