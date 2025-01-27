**Important Information:**

The reason multiple monitors cannot be connected during setup is that Batocera's current implementation of multi-screen support can interfere with detecting the correct output.  

To avoid this, all outputs except the one in use must be disabled. It's essential that the output port you use during setup is the same one you will use for CRT output. **Following this step is crucial for proper configuration.**  

That said, you can still install the script locally using an LCD/OLED monitor, but it must be connected to the same output you plan to use for the CRT.  

**Guidelines for Specific Outputs:**  
- **VGA Output:**  
  * Use a VGA-to-VGA cable to connect an LCD/OLED monitor.  
  * Alternatively, use a VGA-to-HDMI or VGA-to-DP converter.  

- **DVI-I Output:**  
  * Use a DVI-I-to-DVI-I cable to connect an LCD/OLED monitor.  
  * Alternatively, use a DVI-I-to-HDMI or DVI-I-to-DP converter.  

You may also use an EDID emulator (also known as a dummy plug or headless display adapter) for VGA, DVI-I, or DP outputs to simplify setup.

**Recommended Installation Method:**  
It's still recommended to install the script via SSH, as it’s the quickest and most convenient method, provided the PC is connected to the same network.  

You **don’t need a second PC for this**—your mobile phone or laptop can be used with an SSH client.  

**Examples of SSH clients for iOS devices:**  
- Blink Shell  
- Termius  
- a-Shell  
- WebSSH  

**Examples of SSH clients for Android:**  
- ConnectBot  
- JuiceSSH  
- Termius  
- Termux

**Installation**

* Run the CRT Scrip
* Choose the correct input
* Select a correct monitor profile for you CRT.
* Set resolution to 640x480/768x576 (No official theme support for 320x240 at this point)
* Set monitor rotation to "None", NORMAL   (0°) (For a Horizontal setup = Normal)
* Press Enter and skip ADVANCED CONFIGURATION for all 4 option (If you don't know what they mean)
* Default resolution for GunCon2 calibration is (320x240@60Hz)

# Using curl command line tool
 - v41

`bash <(curl -s https://pastebin.com/raw/iC21J0W6 | sed 's/\r$//')`

This command chain downloads the latest version, extracts its contents, moves the desired folder to the desired location, removes unnecessary files and folders, sets permissions for the script file, keeps the backup folder if present and finally executes the script. Each command is executed only if the previous command succeeds, ensuring a smooth execution flow.

If your Graphics card is an R9 380 model you will need to re-run the setup one more time after first run 

``/userdata/system/Batocera-CRT-Script/Batocera_ALLINONE/./Batocera-CRT-Script-v41.sh``

# Manually

Setup via wired or wireless network.

Now before running the script make sure you have connected the correct cables to the correct output on your card that you are going to use.
Also make sure the Tv/Monitor is off or on another Tv AV/Channel during the setup process. 

1) Press the code icon on GitHub and choose **Download Zip**
    
2) Extract the zipfile `Batocera-CRT-Script-main.zip` into a temporary folder on your PC.

3) Access your Batocera installation over the network. 
     See official guide here on how to do so here.
     https://wiki.batocera.org/add_games_bios?s[]=transfer#add_games_bios_files_to_batocera 

4) Drag and drop the `system` folder to your Batocera installation
     The correct path should be
      `/userdata/system`
      Via SMB you are already in the `userdata` folder so just drag and drop the folder.
 
5) Connect to your Batocera installation via SSH 
    See official guide on how to do so here: 
     https://wiki.batocera.org/access_the_batocera_via_ssh
    
6) Via SSH type (Without the Grave Accent Symbols) **`**

`cd /userdata/system/Batocera-CRT-Script/Batocera_ALLINONE`

 - v41

`chmod 755 Batocera-CRT-Script-v41.sh`

`./Batocera-CRT-Script-v41.sh`

Here you will be greeted with some information to read. 
Press Enter and follow the onscreen instructions. 


