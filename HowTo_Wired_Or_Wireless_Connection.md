* Don't have anything else then the CRT connected to the dGPU/APU during setup. 

* Run the CRT Scrip
* Choose the correct input
* Select a correct monitor profile for you CRT.
* Set resolution to 640x480/768x576 (No official theme support for 320x240 at this point)
* Set monitor rotation to "None", NORMAL   (0°) (For a Horizontal setup = Normal)
* Press Enter and skip ADVANCED CONFIGURATION for all 3 option (If you don't know what they mean)
* Select default resolution for GunCon2 (320x240@60Hz)

# Using curl command line tool
 - v41

`bash <(curl -s https://pastebin.com/raw/iC21J0W6 | sed 's/\r$//')`

This command chain downloads the latest version, extracts its contents, moves the desired folder to the desired location, removes unnecessary files and folders, sets permissions for the script file, keeps the backup folder if present and finally executes the script. Each command is executed only if the previous command succeeds, ensuring a smooth execution flow.

If your Graphics card is an R9 380 model you will need to re-run the setup one more time after first run 

``cd /userdata/system/Batocera-CRT-Script/Batocera_ALLINONE``

``./Batocera-CRT-Script-v41.sh``

### There is currently a bug for AMD APU users. 
### VideoMode: Auto in EmulationStation doesn't work. 
### To fix the issue until we have issued a fix is by doing the following after installation.

SSH

`cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_MYZAR_ZFEbHVUE /usr/bin/batocera-resolution`

`batocera-save-overlay`

`reboot`



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


