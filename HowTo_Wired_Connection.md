Setup via wired network.

Now before running the script make sure you have connected the correct cables to the correct output on your card that you are going to use.
Also make sure the Tv/Monitor is off or on another Tv AV/Channel during the setup process. 

1) Press the code icon on GitHub and choose **Download Zip**
    
2) Extract the zipfile `Build-CRT-15KHz-Batocera-V35-main.zip` into a temporary folder on your PC.

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
    
6) Via SSH type

`cd /userdata/system/BUILD_15KHz/Batocera_ALLINONE`

`chmod 755 BUILD_15KHZ_BATOCERA.sh`

`./BUILD_15KHZ_BATOCERA.sh`

Here you will be greeted with some information to read. 
Press Enter and follow the onscreen instructions. 
