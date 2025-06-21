### INSTALLATION INSTRUCTIONS 

[Installation Instructions](https://github.com/ZFEbHVUE/Batocera-CRT-Script/blob/main/HowTo_Wired_Or_Wireless_Connection.md)

## Wiki page

See wiki page for documentation [wiki](https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki)

## Discord
[Discord: Channel #pc-x86_64-support](https://discord.com/invite/JXhfRTr)

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
 - [fishcu](https://github.com/fishcu) - shaders: pixel_aa_xform.slangp & box_filter_aa_xform.slangp

### Testers 
 - GecKoTDF
 - Sirmagb

### Special Thanks
- krahsdevil (Emulation Station assets) 
 
## :video_game::penguin: Batocera-CRT-Script :video_game::penguin:

This bash script will help you setup Batocera on a Crt in 15-25-31kHz
 
 - Complete integration of the [Switchres](https://github.com/antonioginer/switchres/blob/master/README.md) tool (not the api) for switching modelines. (resolutions)
 - Detection of AMD APUs if used with the Cabledeconn DP2VGA listed on the [Wiki](https://wiki.batocera.org/batocera-and-crt#displayport_to_vga_dac) page.
 - Creation of custom EDID during setup for the monitor profile chosen.
 - It will read resolutions from videomodes.conf but switchres will handle the resolution switching not xrandr. 
 - You are free to add your own resolution by editing the file as you choose but keep in mind you need to test if it works for your monitor profile first. 
 
**Keep in mind 320x240 (320x240p) as a boot resolution is not officially supported since there is no Emulation Station Theme support as of now in Batocera.**

It comes pre-configured with all 29 Monitor Profiles Switchres supports.

These pre-configured Monitor Profiles have 50+ resolutions added that should only be used with

 - Standalone Emulators
 - Native Linux Games
 - Non libretro Ports
 - Wine, Flatpak & Steam
 - GroovyMame & Retroarch is preconfigured to use the switchres api.

## 🖥️ Monitor Profile Overview

These are the supported monitor profiles used in `switchres.ini`.  
Each profile defines timings optimized for a specific CRT standard, arcade monitor, or PC display.

---

### 🎮 Generic CRT Standards (15kHz)

| Profile         | Description                                                                 |
|-----------------|-----------------------------------------------------------------------------|
| `arcade_15`     | ✅ **Recommended** for most consumer CRT TVs — safe and widely compatible   |
| `generic_15`    | ✅ **Recommended** fallback for general CRT use                              |
| `ntsc`          | Only for CRT chassis that support **59.94Hz only** (rare)                   |
| `pal`           | Only for CRT chassis that support **50.00Hz only** (rare)                   |

---

### 🕹️ Arcade CRT Profiles

| Category                    | Profile Names                        | Notes                                                |
|----------------------------|--------------------------------------|------------------------------------------------------|
| Fixed Frequency (15kHz)    | `arcade_15`, `arcade_15ex`           | Common for arcade cabinets using 15kHz monitors      |
| Fixed Frequency (25/31kHz) | `arcade_25`, `arcade_31`             | Used for mid- and high-res arcade monitors           |
| Multisync (15/25/31kHz)    | `arcade_15_25`, `arcade_15_31`, `arcade_15_25_31` | For multisync arcade monitors supporting all bands |

---

### 🖥️ VESA & PC Monitor Profiles

| Category        | Profile Names                       | Notes                                      |
|----------------|-------------------------------------|--------------------------------------------|
| VESA GTF Modes | `vesa_480`, `vesa_600`, `vesa_768`, `vesa_1024` | Mimics standard VESA timings (non-CRT safe) |
| 120Hz PC Modes | `pc_31_120`, `pc_70_120`             | For PC CRT monitors capable of 120Hz       |

---

### 🧰 Manufacturer-Specific Arcade Monitors

| Manufacturer     | Models (Profile Names)                            |
|------------------|---------------------------------------------------|
| **Hantarex**     | `h9110`, `polo`, `pstar`                          |
| **Wells Gardner**| `k7000`, `k7131`, `d9200`, `d9400`, `d9800`       |
| **Makvision**    | `m2929`                                           |
| **Wei-Ya**       | `m3129`                                           |
| **Nanao**        | `ms2930`, `ms929`                                 |
| **Rodotron**     | `r666b`                                           |

---

### 🔎 More Info

- 📖 [ArcadeControls Forum Thread – Monitor Timings & Switchres](https://forum.arcadecontrols.com/index.php/topic,116023.0/all.html)
- 🌐 You can also search online for your specific monitor model for compatibility tips and timing suggestions.


## ❗ GPU Compatibility for CRT Output (15kHz)

Batocera's CRT output depends heavily on the GPU and driver capabilities. Here's what works — and what doesn’t — for 15.7 kHz (240p/480i) video signals.

---

### ✅ AMD GPUs – **Recommended**

Batocera includes the [15kHz kernel patchset](https://github.com/D0023R/linux_kernel_15khz), which enables full support for:

- Low-resolution video modes (e.g. 320×240, 640×480i)
- Custom modelines
- Interlaced output
- 15.7 kHz scanrates

This applies to both:
- **`amdgpu` and `radeon` drivers**
- **Discrete GPUs (dGPUs) and APUs**

🔗 A curated list of **supported AMD dGPUs and APUs using the AMDGPU driver** is available in the wiki:  
➡️ [Supported dGPUs & APUs](https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Supported-dGPUs-&-APUs)

---

### ❌ Intel iGPUs – **Not Supported**

All Intel integrated GPUs — across all generations — are **not compatible** with CRT output at 15kHz due to hardcoded limitations in the Intel DRM driver (`i915`):

- 🚫 **Minimum dotclock limits** (~25 MHz), 15kHz video modes
- 🚫 **Strict CVT/GTF-only modeline validation** (non-EDID custom modelines are rejected)
- 🚫 **No legacy CRTC interfaces** for timing control
- 🚫 **Tightly restricted DPLL clock generation**
- 🚫 **EDID dependency**, which prevents unsupported resolutions from loading

> ❗ These are **hardware and driver-level constraints**, not solvable with 15kHz patches. Intel iGPUs are **not supported** for CRT output in Batocera.

**Recommendation:** Use a supported AMD GPU or APU instead.

---

### ⚠️ NVIDIA GPUs – Limited and Fragile Support

#### ✅ Maxwell (1.0 – 2.0) via proprietary drivers
Batocera supports **NVIDIA Maxwell architecture** (GeForce GTX 750 through GTX 900 series) **only with the official NVIDIA proprietary drivers** for 15kHz CRT output.

> ℹ️ This is the **only NVIDIA setup officially supported**, and it works by chance — not by design.  
There is **no guarantee** future NVIDIA driver updates will preserve this compatibility.

#### ⚠️ Older cards using open-source `nouveau`
Some NVIDIA GPUs (pre-Maxwell) **may appear to work** with CRT output using the open-source `nouveau` driver, but:
- There is **no support from the 15kHz patchset**
- Success is **inconsistent**, and varies by card/BIOS.

> 🔧 These cards are **not recommended**, and any success is coincidental.

#### ⚠️ **Older cards via nouveau**
Some legacy NVIDIA cards may function with the open-source `nouveau` driver, but compatibility is **inconsistent** and often unreliable.

**Recommendation:** Go with AMD for proper CRT support and future-proofing.
We only provide official support for **NVIDIA Maxwell cards using proprietary drivers**, and even that may break at any time.
  
