## 🚀 Installation Instructions

📥 **Install the Script**  
Follow the full setup guide here:  
🔗 [Installation Instructions](https://github.com/ZFEbHVUE/Batocera-CRT-Script/blob/main/HowTo_Wired_Or_Wireless_Connection.md)

📚 **Full Documentation**  
Read the Wiki for detailed usage and configuration:  
🔗 [Batocera-CRT-Script Wiki](https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki)

💬 **Need Help?**  
Join the discussion on Discord:  
🔗 [Discord: #pc-x86_64-support](https://discord.com/invite/JXhfRTr)

---

## 📝 Foreword

This project would not have been possible without the help of many skilled and passionate individuals:

### 👨‍💻 Core Developers & Contributors
- **ZFEbHVUE** – Lead developer and main tester  
- **Rion** – CRT wizard and 15kHz support guru  
- **myzar** – NVIDIA driver and compatibility insights  
- **jfroco** – Early CRT output work for Batocera  
- **rtissera** – His knowledge, enthusiasm, and willingness made it possible to add 15kHz patches into Batocera
- **Substring** – Maintainer of GroovyArcade and KMS/SDL improvements  
- **Calamity** – Develops and maintains the 15kHz Linux kernel patches, adding support for new AMD dGPUs/APUs and creating tools like CRT_EmuDriver, GroovyMAME, and Switchres  
- **D0023R (Doozer)** – Maintains the [linux_kernel_15khz](https://github.com/D0023R/linux_kernel_15khz) repository, ensuring Calamity’s patches stay up-to-date with the latest Linux kernel versions
- **dmanlcf** – Maintains 15kHz kernel patches for Batocera

### 👥 Contributors
- **Sirmagb** – Geometry tool idea used in `crt.sh`  
- **Yavimaya** – Code contributions  
- **[fishcu](https://github.com/fishcu)** – Shader author for `pixel_aa_xform.slangp` and `box_filter_aa_xform.slangp`

### 🧪 Testers
- **GecKoTDF** – Hands-on CRT hardware testing  
- **Sirmagb** – Continued validation and feedback

### 🎨 Special Thanks
- **krahsdevil** – Created EmulationStation artwork and assets

---
 
## 🖥️ CRT Setup Script Overview

This Bash script enables **true CRT support** in **Batocera**, including 15kHz, 25kHz, and 31kHz video output.  
Batocera does not natively support CRT displays — this script adds the full support needed for proper signal generation and resolution switching.

---

### ✅ Key Features

- 🔁 **Modeline Switching**  
  Fully integrates the [Switchres tool](https://github.com/antonioginer/switchres/blob/master/README.md) (not the API) to handle resolution switching — *bypassing xrandr*.

- 🧠 **EDID & APU Detection**  
  - Automatically detects **AMD APUs** when using the **CableDeconn DP2VGA** (listed on the [Batocera Wiki](https://wiki.batocera.org/batocera-and-crt#displayport_to_vga_dac)).
  - Generates a **custom EDID** based on your selected monitor profile.

- 📁 **videomodes.conf Integration**  
  Resolutions are read from `videomodes.conf`, but **Switchres handles switching**, not xrandr.  
  You may manually add resolutions, but be sure to test them with your monitor profile first.

---

### ⚠️ Note on 320×240 Boot Resolution

`320x240p` as a **boot resolution** is *not officially supported*,  
as **EmulationStation themes do not currently support it** in Batocera.

---

### 🖼️ Monitor Profiles & Preconfigured Resolutions

- Comes with **29 pre-configured monitor profiles** supported by Switchres.
- Each profile includes **50+ hand-picked resolutions**, optimized for:

  - 🎮 Standalone Emulators (e.g., PCSX2, Dolphin)
  - 🐧 Native Linux Games
  - 📦 Non-Libretro Ports
  - 🍷 Wine, Flatpak & Steam Games

> 🕹️ **RetroArch** (Libretro cores) and **GroovyMAME** are preconfigured to use the **Switchres API** for automatic resolution switching.


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
| VESA GTF Modes | `vesa_480`, `vesa_600`, `vesa_768`, `vesa_1024` | Mimics standard VESA timings  |
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

🔗 A curated list of **supported NVIDIA Maxwell architecture** is available in the wiki:  
➡️ [Supported NVIDIA Maxwell Cards](https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Supported-NVIDIA-Maxwell-Cards-%28Proprietary-Driver%29)

#### ⚠️ Older cards using open-source `nouveau`
Some NVIDIA GPUs (pre-Maxwell) **may appear to work** with CRT output using the open-source `nouveau` driver, but:
- There is **no support from the 15kHz patchset**
- Success is **inconsistent**, and varies by card/BIOS.

> 🔧 These cards are **not recommended**, and any success is coincidental.

**Recommendation:** Go with AMD for proper CRT support and future-proofing.
We only provide official support for **NVIDIA Maxwell cards using proprietary drivers**, and even that may break at any time.
  
