## 🚀 Batocera CRT Script

This script adds CRT output to Batocera, including 15 kHz, 25 kHz, and 31 kHz.

📚 Start with the [Quick Start](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki). That is the short guide for installation. Hardware support and upgrades are on that same page.

The wiki also has [advanced topics](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki/Advanced): calibration, geometry, emulator settings, and the rest of the detail after the picture is on screen.

💬 Help: [Discord ##crt-x86_64](https://discord.com/invite/JXhfRTr)

---

## 🖥️ CRT Setup Script Overview

### ✅ Key Features
- 🕹️ **RetroArch** (Libretro cores) and **GroovyMAME** are preconfigured to use the **Switchres API** for automatic resolution switching.

- 🔁 **Modeline Switching**  
  Fully integrates the [Switchres tool](https://github.com/antonioginer/switchres/blob/master/README.md) (not the API) to handle resolution switching — *bypassing xrandr*.

- 🧠 **EDID & APU Detection**  
  - Automatically detects **AMD APUs** when using the **CableDeconn DP2VGA** (listed on the [Digital to Analog (DAC)](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki/Digital-to-Analog-(DAC)#-displayport-to-vga-dac--cabledeconn-rtd21682166) page).
  - Generates a **custom EDID** based on your selected monitor profile.

- 📁 **videomodes.conf Integration**  
  Resolutions are read from `videomodes.conf`, but **Switchres handles switching**, not xrandr.  
  You may manually add resolutions, but be sure to test them with your monitor profile first.

- 🛠️ **CRT Tools**  
  Calibration tools in the EmulationStation menu for the grid, geometry, and centering the EmulationStation picture.
  🔗 [CRT Tools Guide](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki/CRT-Tools-Guide)

- 🎮 **Handheld support**  
  Confirmed on the Steam Deck (all revisions) and the ROG Ally, including the Ally X. Other USB-C devices with DisplayPort Alt Mode may work.
  🔗 [Handheld & Portable Device Support](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki/Handheld-&-Portable-Device-Support)

- 💡 **HD/CRT Mode Switcher**  
  Switch between an HD display and a CRT without running the CRT script again or restoring. It works on a PC and on a handheld such as a Steam Deck or ROG Ally. One reboot or power cycle changes the mode.
  🔗 [HD/CRT Mode Switcher](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki/HD-CRT-Mode-Switcher)

---

### 🖼️ Monitor Profiles & Preconfigured Resolutions

- Comes with **29 pre-configured monitor profiles** supported by Switchres.
- Each profile includes **50+ hand-picked resolutions**, optimized for:

  - 🎮 Standalone Emulators (e.g., PCSX2, Dolphin)
  - 🐧 Native Linux Games
  - 📦 Non-Libretro Ports
  - 🍷 Wine, Flatpak & Steam Games

🔗 The full profile list is in the wiki: [Select your monitor profile](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki/How-to-CRT-Script-Configuration#step-5-select-your-monitor-profile)

---

## ❗ GPU Compatibility for CRT Output (15kHz)

Batocera's CRT output depends heavily on the GPU and driver capabilities. Here's what works — and what doesn’t — for 15.7 kHz (240p/480i) video signals.

---

### ✅ AMD GPUs – **Recommended**

Batocera includes the [15kHz kernel patchset](https://github.com/D0023R/linux_kernel_15khz), which enables low-resolution modes, custom modelines, interlaced output, and 15.7 kHz scan rates on `amdgpu` and `radeon`.

🔗 [Supported AMD dGPUs & APUs](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki/Supported-AMD-dGPUs-&-APUs)

---

### ❌ Intel iGPUs – **Not Supported**

The Intel `i915` driver blocks 15 kHz output: a minimum dotclock around 25 MHz, CVT/GTF-only modelines, no legacy CRTC timing control, restricted DPLL clocks, and a hard dependence on EDID. The 15 kHz patches do not remove those limits.

---

### ⚠️ NVIDIA GPUs – Limited and Fragile Support

Maxwell support with the proprietary driver is accidental. A later NVIDIA driver can remove it.

🔗 [Supported NVIDIA Maxwell Cards](https://github.com/net-terminal-gene/Batocera-CRT-Script/wiki/Supported-NVIDIA-Maxwell-Cards-(Proprietary-Driver))

Older cards on the open-source `nouveau` driver are outside the 15 kHz patchset. A picture on one of those cards does not mean the card is supported.

---

## 📝 Foreword

This project would not have been possible without the help of many skilled and passionate individuals:

### 👨‍💻 Core Developers
- **ZFEbHVUE** – Lead developer and main tester
- **Rion** – CRT wizard and 15kHz support guru
- **net-terminal-gene** – HD/CRT Mode Switcher, Wayland/X11 Dual-Boot, Steam Deck tester, Arcade Guru, CRT Tools artwork

### 👥 Contributors
- **Sirmagb** – Geometry tool idea's
- **Yavimaya** – Code contributions
- **fishcu** – Shader author for `pixel_aa_xform.slangp` and `box_filter_aa_xform.slangp`
- **myzar** – NVIDIA driver and compatibility insights
- **jfroco** – Early CRT output work for Batocera
- **rtissera** – His knowledge, enthusiasm, and willingness made it possible to add 15kHz patches into Batocera
- **Substring** – Maintainer of GroovyArcade and KMS/SDL improvements
- **Calamity** – Develops and maintains the 15kHz Linux kernel patches, adding support for new AMD dGPUs/APUs and creating tools like CRT_EmuDriver, GroovyMAME, and Switchres
- **D0023R (Doozer)** – Maintains the [linux_kernel_15khz](https://github.com/D0023R/linux_kernel_15khz) repository, ensuring Calamity's patches stay up-to-date with the latest Linux kernel versions
- **dmanlcf** – Maintains 15kHz kernel patches for Batocera

### 🧪 Testers
- **GecKoTDF** – Hands-on CRT hardware testing
- **Sirmagb** – Continued validation and feedback

### 🎨 Special Thanks
- **krahsdevil** – Created EmulationStation artwork and assets

### 📖 Wiki Readers & Fact Checkers
- **MarcoRetro** – Provided key insights on RGB mod behavior and adapter compatibility
