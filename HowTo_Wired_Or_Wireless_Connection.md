# Using curl command line tool

 - v39

`bash <(curl -s https://pastebin.com/raw/itUtQYks)`

 - v40

`bash <(curl -s https://pastebin.com/raw/ZtqQBbyZ)`

This command chain downloads the latest version, extracts its contents, moves the desired folder to the desired location, removes unnecessary files and folders, sets permissions for the script file, and finally executes the script. Each command is executed only if the previous command succeeds, ensuring a smooth execution flow.

If you want to just download it with Curl without executing do this

 - v39

`bash <(curl -s https://pastebin.com/raw/8Gg30fZB)`

 - v40

`bash <(curl -s https://pastebin.com/raw/sMhrHHLP)`

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

 - v39

`chmod 755 Batocera-CRT-Script.sh`

`./Batocera-CRT-Script.sh`

 - v40

`chmod 755 Batocera-CRT-Script.sh`

`./Batocera-CRT-Script-v40.sh`

Here you will be greeted with some information to read. 
Press Enter and follow the onscreen instructions. 


