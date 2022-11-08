#!/bin/bash
clear


echo "#######################################################################"
echo "##							             ##"
echo "##                   15KHz BATOCERA V34 CONFIGURATION                ##"
echo "##							             ##"
echo "## RION(15KHz master) MYZAR(Nvidia) ZFEbHVUE(main coder and Tester)  ##"
echo "##							             ##"
echo "##                            20/02/2022                             ##"
echo "##							             ##"
echo "##             BEFORE USING THE SCRIPT READ THE FOLLOWING TEXT       ##"   
echo "##							             ##"
echo "##              !! USE THIS SCRIPT ON YOUR OWN RISK !!               ##"
echo "##						                     ##"
echo "##           AUTHORS OF THIS SCRIPT WILL NOT BE HELD RESPONSIBLE     ##"
echo "##                      FOR ANY DAMMAGES YOU GET                     ##"
echo "##                                                                   ##"
echo "##           YOU MUST HAVE READ THE 15KHz CRT BATOCERA WIKI PAGE     ##"
echo "##          https://wiki.batocera.org/batocera-and-crt?s[]=crt       ##"
echo "##							             ##"
echo "##	          THIS SCRIPT WORKS ON A LCD SCREEN	             ##"
echo "##              (ALSO IN 15KHz CRT IF YOU ARE ALREADY IN 15)         ##"
echo "##							             ##"
echo "##							             ##"
echo "##           YOU NEED TO HAVE RIGHT CONNECTION FOR 15KHz CRT         ##"
echo "##   AND SOME PROTECTIONS FOR YOUR MONITOR AGAINST BAD FREQUENCIES   ##"
echo "##							             ##"
echo "##	           THE SCRIPT IS OPEN SOURCE                         ##"
echo "##              YOU CAN MODIFY IT / IMPROVE IT / REPORT BUGS         ##"
echo "##							             ##"
echo "##             IF YOU ARE OK WITH THESE CONDITIONS TYPE ENTER        ##"
echo "##				AND .....  		             ##"
echo "##		    HAVE LOTS OF RETRO FUN !!!!  	             ##"
echo "##		                                                     ##"	    
echo "## GREETING TO ALL RETRO DEVELOPERS !! (EMULATOR/DISTRIB/FRONTEND...)##"
echo "##		         AND ALL RETRO GAMERS !!                     ##"	
echo "##                            					     ##"
echo "##  AMD/ATI DVI-I (Boot works) (ES Works) (Games work)               ##"
echo "##          DP    (Boot works) (ES Works) (Games work)               ##"
echo "##          VGA    Not Tested                                        ##"
echo "##          HDMI   Not implemented yet                               ##"
echo "##          DVI-D  Not implemented yet                               ##"
echo "##          DIN    Not implemented yet                               ##"
echo "##                            				 	     ##"
echo "##   INTEL  DVI-I  Not implemented yet                               ##"
echo "##          DP    (Boot works) (ES Works) (Games work)               ##"
echo "##          VGA   (Boot works) (ES Works) (Games don't work)         ##"
echo "##          HDMI   Not implemented yet                               ##"
echo "##          DVI-D  Not implemented yet                               ##"
echo "##          DIN    Not implemented yet                               ##"
echo "##                            				             ##"
echo "##   NVIDIA DVI-I (Boot works) (ES Works) (Games work)               ##"
echo "##          DP    (Boot works) (ES Works) (Games works only 240p)    ##"
echo "##          VGA    Not implemented yet                               ##"
echo "##          HDMI  (Boot works) (ES Works) (Games don't work)         ##"
echo "##          DVI-D  Not implemented yet                               ##"
echo "##          DIN    Not implemented yet                               ##"

echo "##                            					     ##"
echo "#######################################################################"
read 

clear

version_Batocera=$(batocera-es-swissknife  --version)
case $version_Batocera in
	30*)
		echo "Version 30"
		Version_of_batocera="v30"
		version=0
		;;
	31*)
		echo "Version 31"
		Version_of_batocera="v31"
		verion=1
		;;
	32*)
		echo "Version 32"
		Version_of_batocera="v32"
		verion=2
		;;
	33*)
		echo "Version 33"
		Version_of_batocera="v33"
		verion=3
		;;
	34*)
		echo "Version 34"
		Version_of_batocera="v34"
		verion=4
		;;
	35*)
		echo "Version 35"
		Version_of_batocera="v35"
		verion=5
		;;
	36*)
		echo "Version 36 dev"
		Version_of_batocera="v36"
		verion=6
		;;

	*)
		echo "unknown version"
		exit 1
		;;

esac

echo "#######################################################################"
echo "##                     information cards                             ##"
echo "#######################################################################"
#declare -a name                                                                                                                                     
j=0                                                                                                                                                 
for p in /sys/class/drm/card? ; do                                                                                                                  
  id=$(basename `readlink -f $p/device`)                                                                                                            
  temp=$(lspci -mms $id | cut -d '"' -f4,6)    
#  temp=$(lspci -mms $id | cut -d '"' -f4,6 --output-delimiter=" ")  
  name_card[$j]="$temp"                                                                                                                             
  j=`expr $j + 1`                                                                                                                                   
done 
echo "                                                                       "
for var in "${!name_card[@]}" ; do echo "	$((var+1)) : ${name_card[$var]}"; done
echo "                                                                       "
###############################################################
##    TYPE OF GRAPHIC CARD
###############################################################
Drivers_Nvidia_CHOICE="NONE"

case $temp in

	*[Nn][Vv][Ii][Dd][Ii][Aa]*)

	echo "                                                                       "
	echo "#######################################################################"
	echo "##       		YOUR VIDEO CARD IS NVIDIA                          ##"
	echo "#######################################################################"
	echo "                                                                       "

    	TYPE_OF_CARD="NVIDIA"
	echo "                                                                       "
	echo "#######################################################################"
	echo "##    Do you want Nvidia_drivers or NOUVEAU                          ##"
	echo "#######################################################################"
	declare -a Nvidia_drivers_type=( "Nvidia_Drivers" "NOUVEAU" )
	for var in "${!Nvidia_drivers_type[@]}" ; do echo "			$((var+1)) : ${Nvidia_drivers_type[$var]}"; done
	echo "#######################################################################"
	echo "##	     Make your choice 					     ##"
	echo "#######################################################################"
	read choice_Drivers_Nvidia
	Drivers_Nvidia_CHOICE=${Nvidia_drivers_type[$choice_Drivers_Nvidia-1]}
	echo "                    your choice is :  $Drivers_Nvidia_CHOICE           "

        if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
		echo "                                                                       "
		echo "#######################################################################"
		echo "##   What kind of version you want for Nvidia-drivers                ##"
		echo "#######################################################################"
		declare -a Name_Nvidia_drivers_version=( "true" "legacy" "legacy390" "legacy340" )
		for var in "${!Name_Nvidia_drivers_version[@]}" ; do echo "			$((var+1)) : ${Name_Nvidia_drivers_version[$var]}"; done
		echo "#######################################################################"
		echo "##	     Make your choice 					     ##"
		echo "#######################################################################"
		read choice_Name_Drivers_Nvidia
		Drivers_Name_Nvidia_CHOICE=${Name_Nvidia_drivers_version[$choice_Name_Drivers_Nvidia-1]}
		echo "                    your choice is :  $Drivers_Name_Nvidia_CHOICE           "
	fi
    	;;

    	*[Ii][Nn][Tt][Ee][Ll]*)
	echo "                                                                       "
	echo "#######################################################################"
	echo "##       		YOUR VIDEO CARD IS INTEL                           ##"
	echo "#######################################################################"
	echo "                                                                       "

    	TYPE_OF_CARD="INTEL"
    	;;
    	*[Aa][Mm][Dd]* | *[Aa][Tt][Ii]*)
	echo "                                                                       "
	echo "#######################################################################"
	echo "##       		YOUR VIDEO CARD IS AMD/ATI                   ##"
	echo "#######################################################################"
	echo "                                                                       "



    	TYPE_OF_CARD="AMD/ATI"

	###############################################################
	if [[ "$temp" =~ "R9" ]] && [[ "$temp" =~ "380" ]]; then
	echo "                                                                       "
	echo "#######################################################################"
	echo "##       		You have an ATI R9 380/380x                  ##"
	echo "#######################################################################"
	
	R9_380="YES"

	if  grep -q "amdgpu.dc=0" "/boot/EFI/syslinux.cfg" && grep -q "amdgpu.dc=0" "/boot/EFI/BOOT/syslinux.cfg" && grep -q "amdgpu.dc=0" "/boot/boot/syslinux.cfg" && grep -q "amdgpu.dc=0" "/boot/boot/syslinux/syslinux.cfg" ; then
	
		echo "                                                                       "
		echo "#######################################################################"
		echo "##       	    This card is ready for 15KHz                     ##"
		echo "##       	          enter to continue                          ##"
     		echo "#######################################################################"
		echo "                                                                       "
                read
	else

		echo "##       	   This card isn't ready for 15KHz                    ##"
		echo "##       	   enter to update of syslinux.cfg                    ##"

		term_R9_380_amdgpu="mitigations=off amdgpu.dc=0 "
		read
		mount -o remount, rw /boot
		sed  -e "s/mitigations=off/$term_R9_380_amdgpu/g"  /userdata/system/BUILD_15KHz/Boot_configs/syslinux.cfg.default > /boot/EFI/syslinux.cfg
		chmod 755 /boot/EFI/syslinux.cfg

		#############################################################################
		## Copy syslinux for EFI and legacy boot
		#############################################################################
	        cp /boot/EFI/syslinux.cfg /boot/EFI/BOOT/
		cp /boot/EFI/syslinux.cfg /boot/boot
		cp /boot/EFI/syslinux.cfg /boot/boot/syslinux
		echo "#######################################################################"
		echo "##        Do you ready to reboot to make you card 15KHz ready ?      ##"
		echo "#######################################################################"
		read
		reboot
  		exit	
	fi

	else	
		R9_380="NO"

		echo "                                                                       "
		echo "#######################################################################"
		echo "##       	    This card is ready for 15KHz                     ##"
		echo "##       	          enter to continue                          ##"
         	echo "#######################################################################"
		echo "                                                                       "
        	read
	fi


    ;;

    *)
    echo  "BE CAREFULL YOUR CARD IS UNKNOWN "
    exit 1
    ;;

esac

#Type_card="unknown"
#for search_card in amd ati nvidia intel ; do echo "$temp" | egrep -iq "$search_card" && Type_card="$search_card"; done
#echo "You card is : " $Type_card

#####################################################################################################################################################
#####################################################################################################################################################
#clear
echo "#######################################################################"
echo "##                     your card outputs                             ##"
echo "#######################################################################"
echo "                                                                       "
j=0; declare -a OutputVideo; for i in `ls /sys/class/drm |egrep -i "^card.-.*" |sed -e 's/card.-//'`; do OutputVideo[$j]="$i"; j=`expr $j + 1`; done
for var in "${!OutputVideo[@]}" ; do echo "			$((var+1)) : ${OutputVideo[$var]}"; done
echo "                                                                       "

echo "#######################################################################"                                                                      
echo "##                     your connected output                         ##"                                                                      
echo "#######################################################################" 
echo "                                                                       "
valid_card=$(basename $(dirname $(egrep -l "^connected" /sys/class/drm/*/status))|sed -e "s,card0-,,")
echo -e "            you are connected with   $valid_card                    "
echo "                                                                       "

echo "#######################################################################"
echo "##             Make your choice for 15KHz output                     ##"
echo "#######################################################################"
read video_output_choice
video_output=${OutputVideo[$video_output_choice-1]}                           
#############################################################################
echo "                    your choice is :  $video_output 		     "A


########################################################################################
#####################		GENERAL  MONITOR                      ##################
########################################################################################

echo "#######################################################################"
echo "##                     your type of monitor                          ##"
echo "#######################################################################"
if [ "$TYPE_OF_CARD" == "INTEL" ]; then
	if [[ "$video_output" == *"VGA"* ]]; then
		declare -a type_of_monitor=( "arcade_15_SR480" "generic_15_SR480" ) 
        elif  [[ "$video_output" == *"DP"* ]]; then
		declare -a type_of_monitor=( "arcade_15" "arcade_15_25_31"  "arcade_15ex" "generic_15"  "ntsc" "pal") 
        elif  [[ "$video_output" == *"HDMI"* ]]; then
		declare -a type_of_monitor=( "arcade_15_SR480" "generic_15_SR480" ) 
	fi
elif [ "$TYPE_OF_CARD" == "NVIDIA" ]; then
	if [[ "$video_output" == *"DVI"* ]]; then
		declare -a type_of_monitor=( "arcade_15_SR480" "generic_15_SR480" ) 
	elif [[ "$video_output" == *"VGA"* ]]; then
		declare -a type_of_monitor=( "arcade_15_SR480" "generic_15_SR480" "arcade_15_SR240" "generic_15_SR240" ) 
        elif  [[ "$video_output" == *"DP"* ]]; then
		declare -a type_of_monitor=(  "arcade_15_SR240" "generic_15_SR240" ) 
        elif  [[ "$video_output" == *"HDMI"* ]]; then
		declare -a type_of_monitor=( "arcade_15_SR480" "generic_15_SR480" ) 
        else
		declare -a type_of_monitor=( "arcade_15"  "arcade_15_25_31"  "arcade_15ex" "generic_15"  "ntsc" "pal")
	fi	
elif [ "$TYPE_OF_CARD" == "AMD/ATI" ]; then
	declare -a type_of_monitor=( "arcade_15"  "arcade_15_25_31"  "arcade_15ex" "generic_15"  "ntsc" "pal") 
fi


for var in "${!type_of_monitor[@]}" ; do echo "			$((var+1)) : ${type_of_monitor[$var]}"; done
echo "#######################################################################"
echo "##	     Make your choice for monitor type to use                ##"
echo "#######################################################################"
read monitor_choice
monitor_firmware=${type_of_monitor[$monitor_choice-1]}
echo "                    your choice is :  $monitor_firmware                "
monitor_name=$monitor_firmware
monitor_firmware+=".bin"
########################################################################################
#####################		MAME MONITOR                      ######################
########################################################################################

clear
echo "                                                                       "                                                               
echo "#######################################################################"                  
echo "##    Do you want configurate a particular monitor for M.A.M.E       ##"                   
echo "#######################################################################"                                                               
declare -a Mame_monitor_choice=( "YES" "NO" ) 
for var in "${!Mame_monitor_choice[@]}" ; do echo "			$((var+1)) : ${Mame_monitor_choice[$var]}"; done
echo "#######################################################################"
echo "##	     Make your choice 					     ##"
echo "#######################################################################"
read choice_MAME_monitor
monitor_MAME_CHOICE=${Mame_monitor_choice[$choice_MAME_monitor-1]}
echo "                    your choice is :  $monitor_MAME_CHOICE           "

if [ "$monitor_MAME_CHOICE" == "YES" ]; then
	clear
	echo "#######################################################################"
	echo "##                     Your type of monitor for M.A.M.E              ##"
	echo "#######################################################################"

  	if [ "$TYPE_OF_CARD" == "INTEL" ] ||  [ "$TYPE_OF_CARD" == "NVIDIA" ]; then 

		declare -a type_of_monitor=( "arcade_15" "arcade_15_SR480" "arcade_15_SR240" "arcade_15_25_31"  \
			    	             "arcade_15ex"  "generic_15" "generic_15_SR480" "generic_15_SR240" "ntsc" "pal"  )
	else
		declare -a type_of_monitor=( "arcade_15"  "arcade_15_25_31"  \
		                             "arcade_15ex"  "generic_15" "ntsc" "pal" )
	fi

	for var in "${!type_of_monitor[@]}" ; do echo "			$((var+1)) : ${type_of_monitor[$var]}"; done
	echo "#######################################################################"
	echo "## Make your choice for your monitor for playing Groovy M.A.M.E.     ##"
	echo "#######################################################################"
	read monitor_choice_MAME
	monitor_firmware_MAME=${type_of_monitor[$monitor_choice_MAME-1]}
	echo "                    your choice is :  $monitor_firmware_MAME           "
	monitor_name_MAME=$monitor_firmware_MAME
	monitor_firmware_MAME+=".bin"
else
	monitor_name_MAME=$monitor_firmware
	monitor_firmware_MAME+=".bin"
fi


clear
########################################################################################
#####################              BOOT RESOLUTION        ##############################
########################################################################################
echo "                                                                       "                                                               
echo "#######################################################################"                  
echo "##			Boot Resolution                              ##"                   
echo "#######################################################################"          

if [ "$TYPE_OF_CARD" == "INTEL" ] ; then
	if [[ "$video_output" == *"VGA"* ]]; then
		declare -a boot_resolution=( "1280x480ieS" "1280x240ieS" )
	elif  [[ "$video_output" == *"DP"* ]]; then
		declare -a boot_resolution=( "768x576ieS" "640x480ieS" )
       	elif  [[ "$video_output" == *"HDMI"* ]]; then
		declare -a boot_resolution=( "1280x480ieS" "1280x240ieS" )
	fi
elif [ "$TYPE_OF_CARD" == "NVIDIA" ] ; then
	if [[ "$video_output" == *"DVI"* ]]; then
		declare -a boot_resolution=( "1280x480ieS" "1280x240ieS" )
	elif [[ "$video_output" == *"VGA"* ]]; then
		declare -a boot_resolution=( "1280x480ieS" "1280x240ieS" )
        elif  [[ "$video_output" == *"DP"* ]]; then
		declare -a boot_resolution=("1280x240ieS" )
	elif  [[ "$video_output" == *"HDMI"* ]]; then
		declare -a boot_resolution=( "1280x480ieS" "1280x240ieS" )

	fi
else
	declare -a boot_resolution=( "768x576ieS" "640x480ieS" )
fi

for var in "${!boot_resolution[@]}" ; do echo "			$((var+1)) : ${boot_resolution[$var]}"; done                            
echo "#######################################################################"                           
echo "##	     Make your choice for the boot resolution                ##"                          
echo "#######################################################################"                                                               
read boot_resolution_choice                                                                                                                  
boot_resolution=${boot_resolution[$boot_resolution_choice-1]}                                                                                
echo "                    your choice is :  $boot_resolution                 "                                                                                
echo "                                                                       "      
################################################################################################################################
#####################              ES RESOLUTION          ######################################################################
################################################################################################################################

if ([ "$Drivers_Nvidia_CHOICE" == "NONE" ] || [ "$Drivers_Nvidia_CHOICE" == "NOUVEAU" ]); then
	echo "                                                                       "                                                                
	echo "#######################################################################"                           
	echo "##			EmulationStation Resolution                   ##"  
	echo "#######################################################################" 
	if [ "$TYPE_OF_CARD" == "INTEL" ] ; then
		if [[ "$video_output" == *"VGA"* ]]; then
			declare -a ES_resolution=( "1280x576_50iHz" "1280x480_60iHz" )                                                                                
			declare -a ES_resolution_V33=( "1280x576_50" "1280x480_60" )
	        elif  [[ "$video_output" == *"DP"* ]]; then	
			declare -a ES_resolution=( "768x576_50iHz" "640x480_60iHz" )                                                                                
			declare -a ES_resolution_V33=( "768x576" "640x480" )
                elif  [[ "$video_output" == *"HDMI"* ]]; then
			declare -a ES_resolution=( "768x576_50iHz" "640x480_60iHz" )                                                                                
			declare -a ES_resolution_V33=( "768x576" "640x480" )
		fi
	elif [ "$TYPE_OF_CARD" == "NVIDIA" ] ; then

		if [[ "$video_output" == *"DVI"* ]]; then
			declare -a ES_resolution=( "768x576_50iHz" "640x480_60iHz" )                                                                                
			declare -a ES_resolution_V33=( "768x576" "640x480" )
		elif [[ "$video_output" == *"VGA"* ]]; then
			declare -a ES_resolution=( "768x576_50iHz" "640x480_60iHz" )                                                                                
			declare -a ES_resolution_V33=( "768x576" "640x480" )
	        elif  [[ "$video_output" == *"DP"* ]]; then
			declare -a ES_resolution=( "1280x240_60iHz" )                                                                                
			declare -a ES_resolution_V33=( "1280x240" )	
                elif  [[ "$video_output" == *"HDMI"* ]]; then
			declare -a ES_resolution=( "768x576_50iHz" "640x480_60iHz" "1280x576_50iHz" "1280x480_60iHz" "1280x240_60iHz") 
			declare -a ES_resolution_V33=( "768x576" "640x480" "1280x576_50" "1280x480_60" "1280x240_60")
		fi
        else
		declare -a ES_resolution=( "768x576_50iHz" "640x480_60iHz" )                                                                                
		declare -a ES_resolution_V33=( "768x576" "640x480" )
        fi
	for var in "${!ES_resolution[@]}" ; do echo "			$((var+1)) : ${ES_resolution[$var]}"; done                                
	echo "#######################################################################"
	echo "##	     Make your choice for the EmulationStation Resolution    ##"                  
	echo "#######################################################################"                                   
	read es_resolution_choice                                                                                        
	ES_resolution=${ES_resolution[$es_resolution_choice-1]}
	ES_resolution_V33=${ES_resolution_V33[$es_resolution_choice-1]}
	echo "                    Your choice is :  $ES_resolution"    
else

	echo "                                                                       "                                                                
	echo "#######################################################################"                           
	echo "##			EmulationStation Resolution                ##"  
	echo "##                          NVIDIA (Nvidia Drivers)                  ##"
	echo "#######################################################################"                                                               
	if [[ "$video_output" == *"DVI"* ]]; then
		declare -a ES_resolution=( "768x576_50iHz" "640x480_60iHz" )                                                                                
		declare -a ES_resolution_V33=( "768x576" "640x480" )
	elif [[ "$video_output" == *"VGA"* ]]; then
		declare -a ES_resolution=( "1280x576_50iHz" "1280x480_60iHz" "1280x240_60iHz")                                                                                
		declare -a ES_resolution_V33=( "640x480" "1280x576_50" "1280x480_60" "1280x240_60")
        elif  [[ "$video_output" == *"DP"* ]]; then
		declare -a ES_resolution=( "1920x240_60iHz" "1920x256_50iHz")                                                                                
		declare -a ES_resolution_V33=( "1920x240" "1920x256" )	
        elif  [[ "$video_output" == *"HDMI"* ]]; then
		declare -a ES_resolution=( "768x576_50iHz" "640x480_60iHz"  "1280x480_60iHz" "1280x240_60iHz") 
		declare -a ES_resolution_V33=( "768x576" "640x480" "1280x480_60" "1280x240_60")
	fi

	for var in "${!ES_resolution[@]}" ; do echo "			$((var+1)) : ${ES_resolution[$var]}"; done                                
	echo "#######################################################################"
	echo "##	     Make your choice for the EmulationStation Resolution    ##"                  
	echo "#######################################################################"                                   
	read es_resolution_choice                                                                                        
	ES_resolution=${ES_resolution[$es_resolution_choice-1]}
	ES_resolution_V33=${ES_resolution_V33[$es_resolution_choice-1]}
	echo "                    Your choice is :  $ES_resolution"        

fi
################################################################################################################################
################################################################################################################################
################################################################################################################################
clear
echo "                                                                       "
echo "#######################################################################"
echo "##                  EmulationStation ORIENTATION                     ##"
echo "##            MONITOR SETUP (FROM HORIZONTAL POSITION)               ##"
echo "##                                                                   ##"
echo "## HORIZONTAL                     MONITOR  = NORMAL   (0°)           ##"
echo "## VERTICAL   (Counter-Clockwise) MONITOR  = TATE90   (90°)          ##"
echo "## HORIZONTAL (Inverted)          MONITOR  = INVERTED (180°)         ##"
echo "## VERTICAL   (Clockwise)         MONITOR =  TATE270  (-90° or 270°) ##"
echo "##                                                                   ##"
echo "#######################################################################"
declare -a ES_orientation=( "NORMAL" "TATE90" "INVERTED" "TATE270" )
if [ "$TYPE_OF_CARD" == "NVIDIA" ]&&[ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
	declare -a display_rotation=( "normal" "normal" "normal" "normal")
	declare -a display_emulator_rotation=( "normal" "left" "normal" "right")
else
	declare -a display_rotation=( "normal" "right" "inverted" "left")	
	declare -a display_emulator_rotation=( "normal" "normal" "inverted" "normal")
fi
for var in "${!ES_orientation[@]}" ; do echo "                   $((var+1)) : ${ES_orientation[$var]}"; done
echo "#######################################################################"
echo "##             Make your choice for the EmulationStation ORIENTATION ##"
echo "#######################################################################"
read es_rotation_choice
ES_rotation=${ES_orientation[$es_rotation_choice-1]}
display_rotate=${display_rotation[$es_rotation_choice-1]}
display_emulator_rotate=${display_emulator_rotation[$es_rotation_choice-1]}
echo "                    Your choice is :  $ES_rotation"

echo "                                                                       "
echo "#######################################################################"
echo "##                      FOR MAME ROTATING MONITOR                    ##"
echo "##                                                                   ##"
echo "##              FORM THE ACTUAL POSITION OF YOUR MONITOR             ##"
echo "##   ROTATION OF YOUR MONITOR TO PASS TO HORIZONTAL OR TO VERTICAL   ##"
echo "##                                                                   ##"
echo "##   IF YOU WANT TO PLAY HORIZONTAL OR VERTICAL GAMES ON YOUR        ##"
echo "##   MONITOR WITHOUT ROTATION PUT : NONE                             ##"
echo "##                                                                   ##"
echo "#######################################################################"
declare -a Screen_rotating=( "None" "Clockwise" "Counter-Clockwise" )
for var in "${!Screen_rotating[@]}" ; do echo "                   $((var+1)) : ${Screen_rotating[$var]}"; done
echo "#######################################################################"
echo "##             Make your choice for the EmulationStation ORIENTATION ##"
echo "#######################################################################"
read Screen_rotating_choice
Rotating_screen=${Screen_rotating[$Screen_rotating_choice-1]}
echo "                    Your choice is :  $Rotating_screen"

################################################################################################################################
################################################################################################################################
################################################################################################################################
	
if [ "$TYPE_OF_CARD" == "AMD/ATI" ]; then
        
	echo "#######################################################################"
	echo "##               Which kind of drivers do you want to use ?          ##"
        echo "##                                                                   ##"
        echo "##            Please note, RX and R cards older than the R7 240      ##"
        echo "##            just do not support the amdgpu drivers, period, and    ##"
        echo "##            doing this while using them will result in a           ##"
        echo "##                       black screen after reboot.                  ##"
	echo "#######################################################################"

        declare -a driver_ATI=( "AMDGPU" "RADEON" )
	for var in "${!driver_ATI[@]}" ; do echo "			$((var+1)) : ${driver_ATI[$var]}"; done
        echo "#######################################################################" 
	echo "##		Make your choice for your video card                 ##"                  
	echo "#######################################################################"
	read type_of_drivers
        drivers_type=${driver_ATI[$type_of_drivers-1]}
	echo "			Your choice is :   $drivers_type		     "
	echo "                                                                       "
	##############################################################################


	dotclock_min=0	
	dotclock_min_mame=$dotclock_min
	super_width=2560
	super_width_mame=$super_width
	
	if [ "$drivers_type" == "AMDGPU" ]; then

		if [ "$R9_380" == "YES" ]; then

			drivers_amd="amdgpu.dc=0"

		else
           		drivers_amd="radeon.si_support=0 amdgpu.si_support=1 radeon.cik_support=0 amdgpu.cik_support=1"

		fi

	else
		if [ "$R9_380" == "YES" ]; then

			drivers_amd="radeon.si_support=1 amdgpu.si_support=0 radeon.cik_support=1 amdgpu.cik_support=0"

		else
			
			drivers_amd=""

		fi
	fi

	if [[ "$video_output" == *"DP"* ]]; then

                term_dp="DP"
                term_displayport="DisplayPort"
                video_display=${video_output/$term_dp/$term_displayport}
        	nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")

		video_modeline=$term_displayport-$((nbr-1))

       	elif [[ $video_output == *"DVI"* ]]; then

		
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
 
		if [ "$drivers_type" == "AMDGPU" ]; then

			term_DVI=DVI-I

			if [ "$R9_380" == "YES" ]; then
				video_modeline=$term_DVI-$((nbr))
			else
				video_modeline=$term_DVI-$((nbr-1))
			fi


		else

 			term_DVI=DVI
			
			if [ "$R9_380" == "YES" ]; then
				video_modeline=$term_DVI-$((nbr))
			else
				video_modeline=$term_DVI-$((nbr-1))
			fi
		fi  

   	elif [[ "$video_output" == *"VGA"* ]]; then
                
		term_VGA=VGA
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		video_modeline=$term_VGA-$((nbr-1))

	fi


elif [ "$TYPE_OF_CARD" == "INTEL" ]; then

	drivers_amd=""
	
	if [[ "$video_output" == *"DP"* ]]; then
		
		term_dp="DP"
		term_displayport="DisplayPort"
         	video_display=$video_output 
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_modeline=$term_dp-$((nbr))   

		dotclock_min=0
		dotclock_min_mame=$dotclock_min
		super_width=1920
		super_width_mame=$super_width

	elif [[ "$video_output" == *"VGA"* ]]; then

		term_VGA="VGA"
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		video_modeline=$term_VGA-$((nbr))
		
		dotclock_min=25.0
		dotclock_min_mame=$dotclock_min
		super_width=1920
		super_width_mame=$super_width
		
        fi

elif [ "$TYPE_OF_CARD" == "NVIDIA" ]; then
	
	drivers_amd=""
	
	if [[ "$video_output" == *"DP"* ]]; then
		
		term_dp="DP"
		term_displayport="DisplayPort"
         	video_display=$video_output 
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
				video_modeline=$term_dp-$((nbr)) 
				
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=1920
				super_width_mame=$super_width
				
			else
				video_modeline=$term_dp-$((nbr-1)) 
				
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=1920
				super_width_mame=$super_width
			fi
		        	
		else	
			video_modeline=$term_dp-$((nbr)) 
			
		       	dotclock_min=0
			dotclock_min_mame=$dotclock_min
			super_width=1920
			super_width_mame=$super_width
		fi

	elif [[ "$video_output" == *"DVI"* ]]; then
		term_DVI=DVI-I
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
				video_modeline=$term_DVI-$((nbr-1))
				
				dotclock_min=25
				dotclock_min_mame=$dotclock_min
				super_width=1920
				super_width_mame=$super_width

			else
				video_modeline=$term_DVI-$((nbr-1))
				
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=1920
				super_width_mame=$super_width
			fi
		else
			video_modeline=$term_DVI-$((nbr))
			
			dotclock_min=0
			dotclock_min_mame=$dotclock_min
			super_width=1920
			super_width_mame=$super_width
			
		fi
		
	elif [[ "$video_output" == *"HDMI"* ]] ; then
		
		term_HDMI=HDMI
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then	
				video_modeline=$term_HDMI-$((nbr-1))
				
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=1920
				super_width_mame=$super_width
				
			else
				video_modeline=$term_HDMI-$((nbr-1))
				
			 	dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=1920
				super_width_mame=$super_width
				
			fi
		else
			video_modeline=$term_HDMI-$((nbr))
			
			dotclock_min=25.0
			dotclock_min_mame=$dotclock_min
			super_width=1920
			super_width_mame=$super_width
			
		fi

        elif [[ "$video_output" == *"VGA"* ]] ; then
		
		term_VGA=VGA
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then	
				video_modeline=$term_VGA-$((nbr-1))
				
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=1920
				super_width_mame=$super_width
				
			else
				video_modeline=$term_VGA-$((nbr-1))
				
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_widthe=1920
				super_width_mame=$super_width
				
			fi
		else
			video_modeline=$term_VGA-$((nbr))
			
			dotclock_min=0
			dotclock_min_mame=$dotclock_min
			super_width=1920
			super_width_mame=$super_width
			
		fi
        fi
fi


#############################################################################
## Make the boot writable
#############################################################################

mount -o remount, rw /boot

#############################################################################
# first time using the script save the batocera-boot.conf batocera-boot.conf.bak
#############################################################################

if [ ! -f "/boot/batocera-boot.conf.bak" ];then
	cp /boot/batocera-boot.conf /boot/batocera-boot.conf.bak
fi

cp /boot/batocera-boot.conf  /boot/batocera-boot.conf.tmp

#############################################################################
# choose #nvidia-driver (NOUVEAU) or nvidia-driver=true (nvidia driver)
#############################################################################
if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
	if   [ "$Drivers_Name_Nvidia_CHOICE" == "true" ]; then
		sed 's/.*nvidia-driver=.*/nvidia-driver=true/'  	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]; then
		sed 's/.*nvidia-driver=.*/nvidia-driver=legacy/'	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]; then
		sed 's/.*nvidia-driver=.*/nvidia-driver=legacy390/' 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
        elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
		sed 's/.*nvidia-driver=.*/nvidia-driver=legacy340/'  	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		echo "problems of Nvidia driver name"
	fi	
else
# test must be changed form the next versions for Batocera >= v36. 
	if [ "$Drivers_Nvidia_CHOICE" == "NOUVEAU" ]&&[ "$Version_of_batocera" == "v36" ]; then
		sed 's/.*nvidia-driver=.*/nvidia-driver=false/'   		/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		sed 's/.*nvidia-driver=.*/#nvidia-driver=true/'   		/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	fi
fi

cp /boot/batocera-boot.conf.tmp  /boot/batocera-boot.conf
rm /boot/batocera-boot.conf.tmp 

chmod 755 /boot/batocera-boot.conf

#############################################################################
## Copy of the right syslinux for your write device
#############################################################################

# first time using the script save the syslinux.cfg in syslinux.cfg

if [ ! -f "/boot/EFI/syslinux.cfg.bak" ];then
	cp /boot/EFI/syslinux.cfg /boot/EFI/syslinux.cfg.bak
fi


###  Condition to be reviewed


sed -e "s/\[amdgpu_drivers\]/$drivers_amd/g" -e "s/\[card_output\]/$video_output/g" \
    -e "s/\[monitor\]/$monitor_firmware/g" -e "s/\[card_display\]/$video_display/g" \
    -e "s/\[boot_resolution\]/$boot_resolution/g"  /userdata/system/BUILD_15KHz/Boot_configs/syslinux.cfg-generic-Batocera \
     >  /boot/EFI/syslinux.cfg


chmod 755 /boot/EFI/syslinux.cfg

#############################################################################
## Copy syslinux for EFI and legacy boot
#############################################################################

cp /boot/EFI/syslinux.cfg /boot/EFI/BOOT/
cp /boot/EFI/syslinux.cfg /boot/boot/
cp /boot/EFI/syslinux.cfg /boot/boot/syslinux/

#######################################################################################

if [[ "$video_output" == *"DP"* ]]; then                                                                                                       
                                                                                                                                             
        cp /userdata/system/BUILD_15KHz/etc_configs/Monitors_config/10-monitor.conf-DP /etc/X11/xorg.conf.d/10-monitor.conf                                               
        chmod 644 /etc/X11/xorg.conf.d/10-monitor.conf                                                                                       
                                                                                                                                             
elif [[ "$video_output" == *"DVI"* ]]||[[ "$video_output" == *"VGA"* ]]||[[ "$video_output" == *"HDMI"* ]]; then                                                                                                    
                                                                                                                                             
        cp /userdata/system/BUILD_15KHz/etc_configs/Monitors_config/10-monitor.conf-DVI /etc/X11/xorg.conf.d/10-monitor.conf                                              
        chmod 644 /etc/X11/xorg.conf.d/10-monitor.conf                                                                                       
                                                                                                                                             
else                                                                                                                                         
                                                                                                                                             
        echo "####################################################"                                     
        echo "###   UNDER CONSTRUCTION                         ###"                                      
        echo "####################################################"                                                                         
	exit 1                                                                                                                                           
fi

# first time using the script save the 20-amdgpu.conf  in 20-amdgpu.conf.bak
if [ ! -f "/etc/X11/xorg.conf.d/20-amdgpu.conf.bak" ];then
	cp /etc/X11/xorg.conf.d/20-amdgpu.conf /etc/X11/xorg.conf.d/20-amdgpu.conf.bak
fi

cp /userdata/system/BUILD_15KHz//etc_configs/Monitors_config/20-amdgpu.conf /etc/X11/xorg.conf.d/20-amdgpu.conf
chmod 644 /etc/X11/xorg.conf.d/20-amdgpu.conf  

# first time using the script save the 20-radeon.conf  in 20-radeon.conf.bak
if [ ! -f "/etc/X11/xorg.conf.d/20-radeon.conf.bak" ];then                      
        cp /etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-radeon.conf.bak
fi 

cp /userdata/system/BUILD_15KHz/etc_configs/Monitors_config/20-radeon.conf /etc/X11/xorg.conf.d/20-radeon.conf
chmod 644 /etc/X11/xorg.conf.d/20-radeon.conf

#######################################################################################
## Put EDID (Extended Display Identification Data) metadata formats for display devices 
#######################################################################################

cp -rf /userdata/system/BUILD_15KHz/Firmware_configs/edid /lib/firmware/

#######################################################################################
## Batocera-resolution and EmulationStation-standalone
## Disable EmulationStation from forcing 60 Hz in Emulationstation-standalone
#######################################################################################

# first time using the script save the batocera-resolution in batocera-resolution.bak                                     
                                                                                                     
if [ ! -f "/usr/bin/batocera-resolution.bak" ];then                                                           
	cp /usr/bin/batocera-resolution /usr/bin/batocera-resolution.bak                         
fi 
if [  -f "/usr/bin/emulationstation-standalone" ];then                                             
		cp /usr/bin/emulationstation-standalone /usr/bin/emulationstation-standalone.bak
     	fi
if [ ! -f "/usr/lib/python3.10/site-packages/configgen/generators/mame/mameGenerator.py.bak" ];then
	cp /usr/lib/python3.10/site-packages/configgen/generators/mame/mameGenerator.py /usr/lib/python3.10/site-packages/configgen/generators/mame/mameGenerator.py.bak
fi

## Only for Batocera >= V32
case $Version_of_batocera in
	v32)
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/batocera-resolution-v32 /usr/bin/batocera-resolution
		chmod 755 /usr/bin/batocera-resolution
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/emulationstation-standalone-v32 /usr/bin/emulationstation-standalone                                    
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/BUILD_15KHz/etc_configs/switchres.ini-generic-v32 > /etc/switchres.ini
		chmod 755 /etc/switchres.ini

	;;
	v33)
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/batocera-resolution-v33 /usr/bin/batocera-resolution
		chmod 755 /usr/bin/batocera-resolution 
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/emulationstation-standalone-v33 /usr/bin/emulationstation-standalone                                    
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/BUILD_15KHz/etc_configs/switchres.ini-generic-v33 > /etc/switchres.ini
		chmod 755 /etc/switchres.ini

	;;
	v34)
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/batocera-resolution-v34 /usr/bin/batocera-resolution
		chmod 755 /usr/bin/batocera-resolution
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/emulationstation-standalone-v34 /usr/bin/emulationstation-standalone                                    
		chmod 755 /usr/bin/emulationstation-standalone
		###############################################################################################################################################
#		cp /userdata/system/BUILD_15KHz/Mame_configs/mameGenerator.py-v34 /usr/lib/python3.10/site-packages/configgen/generators/mame/mameGenerator.py
		###############################################################################################################################################
		sed -e "s/\[monitor-name\]/$monitor_name/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/BUILD_15KHz/etc_configs/switchres.ini-generic-v34 > /etc/switchres.ini
		chmod 755 /etc/switchres.ini

	;;
	v35)
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/batocera-resolution-v35 /usr/bin/batocera-resolution
		chmod 755 /usr/bin/batocera-resolution
	       	cp /userdata/system/BUILD_15KHz/UsrBin_configs/emulationstation-standalone-v35 /usr/bin/emulationstation-standalone                                    
		chmod 755 /usr/bin/emulationstation-standalone
		###############################################################################################################################################
#		cp /userdata/system/BUILD_15KHz/Mame_configs/mameGenerator.py-v35 /usr/lib/python3.10/site-packages/configgen/generators/mame/mameGenerator.py
		###############################################################################################################################################
		sed -e "s/\[monitor-name\]/$monitor_name/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/BUILD_15KHz/etc_configs/switchres.ini-generic-v35 > /etc/switchres.ini
		chmod 755 /etc/switchres.ini

		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			# comaeback to v35 version
			cp /userdata/system/BUILD_15KHz/UsrBin_configs/Nvidia/batocera-nvidia-v35 /usr/bin/batocera-nvidia
			chmod 755 /usr/bin/batocera-nvidia
			cp /userdata/system/BUILD_15KHz/etc_configs/Nvidia/S05nvidia-v35  /etc/init.d/S05nvidia
			chmod 755 /etc/init.d/S05nvidia
		else
			# correction from V36 (dmanlfc)
			cp /userdata/system/BUILD_15KHz/UsrBin_configs/Nvidia/batocera-nvidia.patch /usr/bin/batocera-nvidia
			chmod 755 /usr/bin/batocera-nvidia
			cp /userdata/system/BUILD_15KHz/etc_configs/Nvidia/S05nvidia.patch  /etc/init.d/S05nvidia
			chmod 755 /etc/init.d/S05nvidia

		fi

	;;
	v36)
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/batocera-resolution-v36 /usr/bin/batocera-resolution
		chmod 755 /usr/bin/batocera-resolution 
		cp /userdata/system/BUILD_15KHz/UsrBin_configs/emulationstation-standalone-v36 /usr/bin/emulationstation-standalone                                    
		chmod 755 /usr/bin/emulationstation-standalone
		###############################################################################################################################################
#		cp /userdata/system/BUILD_15KHz/Mame_configs/mameGenerator.py-v36 /usr/lib/python3.10/site-packages/configgen/generators/mame/mameGenerator.py
		###############################################################################################################################################
		sed -e "s/\[monitor-name\]/$monitor_name/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/BUILD_15KHz/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		chmod 755 /etc/switchres.ini
	;;
	*)
		echo "PROBLEM OF VERSION"
		exit 1;
	;;

esac

#######################################################################################                                                      
## Remove Beta name from splash screen if using a beta.                                                                                                      
#######################################################################################  
if [ -f "/usr/share/batocera/splash/splash.srt" ];then
	mv /usr/share/batocera/splash/splash.srt /usr/share/batocera/splash/splash.srt.bak
fi
#######################################################################################                                                      
## make splash screen rotation if using tate mode (right or left).                                                                                                      
#######################################################################################  
if [ ! -f "/usr/share/batocera/splash/boot-logo.png.bak" ]; then
	cp /usr/share/batocera/splash/boot-logo.png /usr/share/batocera/splash/boot-logo.png.bak
fi 
cp /userdata/system/BUILD_15KHz/Boot_logos/boot-logo.png /usr/share/batocera/splash/boot-logo.png 
if [ "$ES_rotation" == "TATE90" ];then
	cp /userdata/system/BUILD_15KHz/Boot_logos/boot-logo_90.png /usr/share/batocera/splash/boot-logo.png 
fi
if [ "$ES_rotation" == "INVERTED" ];then
	cp /userdata/system/BUILD_15KHz/Boot_logos/boot-logo_180.png /usr/share/batocera/splash/boot-logo.png 
fi
if [ "$ES_rotation" == "TATE270" ]; then
	cp /userdata/system/BUILD_15KHz/Boot_logos/boot-logo_270.png /usr/share/batocera/splash/boot-logo.png  
fi
#######################################################################################
#######################################################################################
## 		USB Arcade Encoders (multiple choices) for Arcade cabinet 
#######################################################################################
#######################################################################################

echo "                                                                       "                                                               
echo "#######################################################################"                           
echo "##    USB Arcade Encoder(s) :  Multiple choices are possible         ##"                           
echo "#######################################################################"                                                               
declare -a Encoder_inputs=\($(ls -1 /dev/input/by-id/| tr "\012" " "| sed -e's, ," ",g' -e 's,^,",' -e 's," "$,",')\)                                                                                   
for var in "${!Encoder_inputs[@]}" ; do echo "			$((var+1)) : ${Encoder_inputs[$var]}"; done                            
echo "			0 : Exit for USB Arcade Encoder(s)                   "
echo "#######################################################################"  
echo "##                                                                   ##"
echo "##            Make your choice(s) for one two or more                ##"
echo "##  for several encoders put virgule or space between your choices   ##"
echo "##                                                                   ##"
echo "##  If you don't have an Arcade Encoder(s) or if you want to let     ##"
echo "##       batocera configure automatically your Arcade Encoder(s)     ##"
echo "##                        press 0 or enter                           ##"
echo "##                                                                   ##"
echo "#######################################################################"   
                   
read Encoder_choice
if [ "x$Encoder_choice" != "x0" ] ; then
var_choix="`echo $Encoder_choice | sed -e 's/,/ /g'`"
for i in $var_choix; do echo "                    your choice is :  ${Encoder_inputs[$i-1]}" ; touch /usr/share/batocera/datainit/system/configs/xarcade2jstick/${Encoder_inputs[$((i-1))]};done                                               
else 
	echo "No USB Arcade encoder(s) has been choosen"
fi
echo "                                                                       "
echo "#######################################################################"
echo "##							             ##"
echo "##             BEFORE YOU PRESS ENTER READ THE FOLLOWING TEXT        ##"   
echo "##							             ##"
echo "##      REMEMBER AUTHORS OF THIS SCRIPT WILL BE NOT RESPONSIBLE      ##"
echo "##                      FOR ANY DAMAGES TO YOUR CRT                  ##"
echo "##							             ##"
echo "##                     DO A SHUTDOWN OF YOUR SYSTEM                  ##"
echo "##         BE SURE YOU PUT THE RIGHT CABLE AND CONNECTION FOR 15KHz  ##"
echo "##       BE SURE YOU HAVE SOME PROTECTIONS FOR YOUR MONITOR          ##"
echo "##							             ##"
echo "##    RESTART YOUR BATOCERA SYSTEM AND HAVE FUN IN 15KHz EXPERIENCE  ##"
echo "##							             ##"
echo "#######################################################################"
read 

#######################################################################################
## Save in compilation in batocera image
#######################################################################################
batocera-save-overlay
#######################################################################################
## Put the custom file for the 15KHz modelines for ES and Games 
#######################################################################################
if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then

	if [  -f "/userdata/system/99-nvidia.conf" ]; then                                                                                                                                                                                                 
		cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak                                                                                                                                                                  
	fi 


	# MYZAR's WORK and TESTS : THX DUDE !!
	cp /userdata/system/BUILD_15KHz/System_configs/Nvidia/99-nvidia.conf-generic  /userdata/system/99-nvidia.conf
	chmod 644 /userdata/system/99-nvidia.conf



	if [ "$ES_resolution" == "640x480_60iHz" ]; then
		es_res_60iHz=""                                                                                                      
        	es_res_50iHz="#"
		es_SR_res_60iHz="#"                                                                                                      
        	es_SR_res_50iHz="#"
 		if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then	
        		es_customsargs="es.customsargs=--screensize 640 480 --screenoffset 00 00"	
		else
			es_customsargs="es.customsargs=--screensize 480 640 --screenoffset 00 00"	
		fi
	elif [[ "$ES_resolution" == "768x576_50iHz" ]]; then                                                                                               
		es_res_60iHz="#"                                                                                                      
        	es_res_50iHz=""
		es_SR_res_60iHz="#"                                                                                                      
        	es_SR_res_50iHz="#"
 		if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then	
        		es_customsargs="es.customsargs=--screensize 768 576 --screenoffset 00 00"	
		else
			es_customsargs="es.customsargs=--screensize 576 768 --screenoffset 00 00"	
		fi
	elif [ "$ES_resolution" == "1920x240_60iHz" ]; then 
		es_res_60iHz="#"                                                                                                      
        	es_res_50iHz="#"
		es_SR_res_60iHz=""                                                                                                      
        	es_SR_res_50iHz="#"
 		if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then	
        		es_customsargs="es.customsargs=--screensize 1920 240 --screenoffset 00 00"	
		else
			es_customsargs="es.customsargs=--screensize 240 1920 --screenoffset 00 00"	
		fi
	elif [ "$ES_resolution" == "1920x256_50iHz" ]; then 
		es_res_60iHz="#"                                                                                                      
        	es_res_50iHz="#"
		es_SR_res_60iHz="#"                                                                                                      
        	es_SR_res_50iHz=""
 		if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then	
        		es_customsargs="es.customsargs=--screensize 1920 256 --screenoffset 00 00"	
		else
			es_customsargs="es.customsargs=--screensize 256 1920 --screenoffset 00 00"	
		fi
	else 
        	echo "#### NO RESOLUTION HERE"        
	fi

	sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" -e "s/\[1920x240\]/$es_SR_res_60iHz/g" -e "s/\[1920x256\]/$es_SR_res_50iHz/g" /userdata/system/BUILD_15KHz/System_configs/Nvidia/custom-es-config-Nvidia-generic >  /userdata/system/custom-es-config

	chmod 755  /userdata/system/custom-es-config

else

	if [ -f "/userdata/system/99-nvidia.conf" ]; then		
		cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
        	rm /userdata/system/99-nvidia.conf 
	fi 	


	if [ "$ES_resolution" == "640x480_60iHz" ]; then
		es_res_60iHz=""
        	es_res_50iHz="#"
		es_SR_res_60iHz="#"
        	es_SR_res_50iHz="#"
		es_SR_res_60Hz="#"
 		if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
        		es_customsargs="es.customsargs=--screensize 640 480 --screenoffset 00 00"
		else
			es_customsargs="es.customsargs=--screensize 480 640 --screenoffset 00 00"
		fi
	elif [ "$ES_resolution" == "768x576_50iHz" ]; then
		es_res_60iHz="#"
        	es_res_50iHz=""
		es_SR_res_60iHz="#"
        	es_SR_res_50iHz="#"
		es_SR_res_60Hz="#"
        	if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
        		es_customsargs="es.customsargs=--screensize 768 576 --screenoffset 00 00"
		else
			es_customsargs="es.customsargs=--screensize 576 768 --screenoffset 00 00"
		fi
	elif [ "$ES_resolution" == "1280x480_60iHz" ]; then
		es_res_60iHz="#"
        	es_res_50iHz="#"
		es_SR_res_60iHz=""
        	es_SR_res_50iHz="#"
		es_SR_res_60Hz="#"
 		if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
        		es_customsargs="es.customsargs=--screensize 1280 480 --screenoffset 00 00"
		else
			es_customsargs="es.customsargs=--screensize 480 1280 --screenoffset 00 00"
		fi
	elif [ "$ES_resolution" == "1280x576_50iHz" ]; then
		es_res_60iHz="#"

        	es_res_50iHz="#"
		es_SR_res_60iHz="#"
        	es_SR_res_50iHz=""
		es_SR_res_60Hz="#"
 		if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
        		es_customsargs="es.customsargs=--screensize 1280 576 --screenoffset 00 00"
		else
			es_customsargs="es.customsargs=--screensize 576 1280 --screenoffset 00 00"
		fi
	elif [ "$ES_resolution" == "1280x240_60iHz" ]; then
		es_res_60iHz="#"
        	es_res_50iHz="#"
		es_SR_res_60iHz="#"
        	es_SR_res_50iHz="#"
		es_SR_res_60Hz=""
 		if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
        		es_customsargs="es.customsargs=--screensize 1280 240 --screenoffset 00 00"
		else
			es_customsargs="es.customsargs=--screensize 240 1280 --screenoffset 00 00"
		fi
	else
        	echo "#### NO RESOLUTION HERE"
	fi

	if [ "$TYPE_OF_CARD" == "AMD/ATI" ] && [[ "$video_output" == *"DP"* ]]; then

		DP_Modeline=""
		DVI_Modeline="#"

	else
		DP_Modeline="#"
		DVI_Modeline=""
	fi

	case $monitor_name in

		arcade_15)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[DVI-I\]/$DVI_Modeline/g" -e "s/\[DP\]/$DP_Modeline/g" -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" -e "s/\[1280x480\]/$es_SR_res_60iHz/g" -e "s/\[1280x576\]/$es_SR_res_50iHz/g" -e "s/\[1280x240\]/$es_SR_res_60Hz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-arcade_15 >  /userdata/system/custom-es-config
		;;
		arcade_15_SR240)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[DVI-I\]/$DVI_Modeline/g" -e "s/\[DP\]/$DP_Modeline/g" -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" -e "s/\[1280x480\]/$es_SR_res_60iHz/g" -e "s/\[1280x576\]/$es_SR_res_50iHz/g" -e "s/\[1280x240\]/$es_SR_res_60Hz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-arcade_15 >  /userdata/system/custom-es-config
		;;
		arcade_15_SR480)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[DVI-I\]/$DVI_Modeline/g" -e "s/\[DP\]/$DP_Modeline/g"  -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" -e "s/\[1280x480\]/$es_SR_res_60iHz/g" -e "s/\[1280x576\]/$es_SR_res_50iHz/g" -e "s/\[1280x240\]/$es_SR_res_60Hz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-arcade_15 >  /userdata/system/custom-es-config

		;;
		arcade_15_25)
		;;
		arcade_15_25_31)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[DVI-I\]/$DVI_Modeline/g" -e "s/\[DP\]/$DP_Modeline/g"  -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-arcade_15_25_31 >  /userdata/system/custom-es-config
		;;
		arcade_15_31)
		;;
		arcade_15ex)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-arcade_15ex >  /userdata/system/custom-es-config
		;;
		arcade_25)
		;;
		arcade_31)
		;;
		d9200)
		;;
		d9400)
		;;
		d9800)
		;;
		generic_15)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[DVI-I\]/$DVI_Modeline/g" -e "s/\[DP\]/$DP_Modeline/g"  -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" -e "s/\[1280x480\]/$es_SR_res_60iHz/g" -e "s/\[1280x576\]/$es_SR_res_50iHz/g" -e "s/\[1280x240\]/$es_SR_res_60Hz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-generic_15 >  /userdata/system/custom-es-config
		;;
		generic_15_SR240)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[DVI-I\]/$DVI_Modeline/g" -e "s/\[DP\]/$DP_Modeline/g"   -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" -e "s/\[1280x480\]/$es_SR_res_60iHz/g" -e "s/\[1280x576\]/$es_SR_res_50iHz/g" -e "s/\[1280x240\]/$es_SR_res_60Hz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-generic_15 >  /userdata/system/custom-es-config

		;;
		generic_15_SR480)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[DVI-I\]/$DVI_Modeline/g" -e "s/\[DP\]/$DP_Modeline/g"  -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" -e "s/\[1280x480\]/$es_SR_res_60iHz/g" -e "s/\[1280x576\]/$es_SR_res_50iHz/g" -e "s/\[1280x240\]/$es_SR_res_60Hz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-generic_15 >  /userdata/system/custom-es-config

		;;
		h9110)
		;;
		k7000)
		;;
		k7131)
		;;
		m2929)
		;;
		m3129)
		;;
		ms2930)
		;;
		ms929)
		;;
		ntsc)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-ntsc >  /userdata/system/custom-es-config
		;;
		pal)
		sed -e "s/\[card_display\]/$video_modeline/g" -e "s/\[640x480\]/$es_res_60iHz/g" -e "s/\[768x576\]/$es_res_50iHz/g" /userdata/system/BUILD_15KHz/System_configs/Custom-es-config_v34/custom-es-config-pal >  /userdata/system/custom-es-config
		;;
		pc_31_120)
		;;
		pc_70_120)
		;;
		polo)
		;;
		pstar)
		;;
		r666b)
		;;
		vesa_1024)
		;;
		vesa_480)
		;;
		vesa_600)
		;;
		vesa_768)
		;;
	
		*)
		;;
	esac

	chmod 755 /userdata/system/custom-es-config

fi
#######################################################################################
# Create a first_script.sh for exiting of Emulationstatio
#######################################################################################
## if the folder doesn't exist, it will be create now
if [ ! -d "/userdata/system/scripts" ];then
	mkdir /userdata/system/scripts
fi

if [ "$TYPE_OF_CARD" == "NVIDIA" ]&&[ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
	AMD_ATI_first_script="#"
	Nvidia_first_script=""
else
	AMD_ATI_first_script=""
	Nvidia_first_script="#"
fi

sed -e "s/\[display_emulator_rotation\]/$display_emulator_rotate/g" -e "s/\[display_ES_rotation\]/$display_rotate/g" -e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$ES_resolution_V33/g" -e "s/\[AMD_ATI_first_script\]/$AMD_ATI_first_script/g" -e "s/\[Nvidia_first_script\]/$Nvidia_first_script/g"  /userdata/system/BUILD_15KHz/System_configs/First_script/first_script.sh-generic-v33  >  /userdata/system/scripts/first_script.sh

chmod 755 /userdata/system/scripts/first_script.sh

#######################################################################################
## Copy of batocera.conf for Libretro cores for use with Switchres
#######################################################################################
# first time using the script save the batocera.conf in batocera.conf.bak                                                                                                                                                                          
if [ ! -f "/userdata/system/batocera.conf.bak" ];then                                                                                                                                                                                                 
	cp /userdata/system/batocera.conf /userdata/system/batocera.conf.bak                                                                                                                                                                  
fi      

cp /userdata/system/batocera.conf.bak /userdata/system/batocera.conf


#######################################################################################
## how to center EmulationStation
#######################################################################################

echo "## ES Settings, See wiki page on how to center EmulationStation" 	>> /userdata/system/batocera.conf
echo $es_customsargs 							>> /userdata/system/batocera.conf

#######################################################################################"		
## CRT GLOBAL CONFIG RETROARCH
#######################################################################################"
echo "###################################################"		>> /userdata/system/batocera.conf
echo "#CRT CONFIG RETROARCH" 						>> /userdata/system/batocera.conf
echo "###################################################"	 	>> /userdata/system/batocera.conf
echo "global.retroarch.menu_driver=rgui" 				>> /userdata/system/batocera.conf
echo "global.retroarch.menu_show_advanced_settings=true" 		>> /userdata/system/batocera.conf
echo "global.retroarch.menu_enable_widgets=false" 			>> /userdata/system/batocera.conf
echo "global.retroarch.crt_switch_resolution = \"4\"" 			>> /userdata/system/batocera.conf
if [ "$dotclock_min" == "25.0" ]; then
	echo "global.retroarch.crt_switch_resolution_super = \"$super_width\""   >> /userdata/system/batocera.conf
else
	echo "global.retroarch.crt_switch_resolution_super = \"0\""	 	>> /userdata/system/batocera.conf
fi
echo "global.retroarch.crt_switch_hires_menu = \"true\"" 		>> /userdata/system/batocera.conf
echo "global.smooth=0" 							>> /userdata/system/batocera.conf
echo "global.rewind=0" 						        >> /userdata/system/batocera.conf
echo "global.shaderset=none" 						>> /userdata/system/batocera.conf
echo "global.bezel=none" 						>> /userdata/system/batocera.conf
echo "global.bezel_stretch=0" 						>> /userdata/system/batocera.conf
echo "global.bezel.tattoo=0" 						>> /userdata/system/batocera.conf
echo "global.hud=none" 							>> /userdata/system/batocera.conf
echo "###################################################"		>> /userdata/system/batocera.conf
#########################################################################################################
##  DISABLE GLOBAL NOTIFICATIONS  
#########################################################################################################
echo "##  Disable Retroarch Notifications for setting refresh rate" 	  >> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_refresh_rate = \"false\""	 	>> /userdata/system/batocera.conf
echo "## Change Notifications Size. Default is 32 (way to big) but 10 looks better on a CRT " >> /userdata/system/batocera.conf
echo "global.retroarch.video_font_size = 10"					>> /userdata/system/batocera.conf
echo "### Disable Everything with notifications"					>> /userdata/system/batocera.conf
echo "global.retroarch.settings_show_onscreen_display = \"false\""      	>> /userdata/system/batocera.conf
#########################################################################################################
##  SOME GLOBAL NOTIFICATIONS CAN BE AVOID WITH REPLACING TRUE BY FALSE    
#########################################################################################################
echo "## global notifications can be avoid with replacing \"true\" by \"false\"" >> /userdata/system/batocera.conf 
echo "global.retroarch.notification_show_autoconfig = \"true\""			>> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_cheats_applied = \"true\""   		>> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_config_override_load = \"true\""	>> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_fast_forward = \"true\""		>> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_netplay_extra = \"true\""		>> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_patch_applied = \"true\""		>> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_remap_load = \"true\"" 		>> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_screenshot = \"true\""			>> /userdata/system/batocera.conf
echo "global.retroarch.notification_show_set_initial_disk = \"true\""		>> /userdata/system/batocera.conf
echo "windows.bezel=none"							>> /userdata/system/batocera.conf 
echo "windows.bezel_stretch=0"							>> /userdata/system/batocera.conf 
echo "windows.bezel.tattoo=0"							>> /userdata/system/batocera.conf 
#######################################################################################
##  Rotation of EmulationStation     
#######################################################################################

term_rotation="display.rotate="
term_es_rotation=$term_rotation$((es_rotation_choice-1))
echo "# ES ROTATION  MODE" >> /userdata/system/batocera.conf
echo $term_es_rotation >> /userdata/system/batocera.conf

#######################################################################################                  
## Mame initialisation Batocera not for RetroLX at this time                                                                                   
#######################################################################################         
cd /usr/bin/mame                                                                                        
./mame -cc
case $Version_of_batocera in
	v32)
		if [ ! -d "/userdata/system/.mame" ]; then                                                              

          		mkdir /userdata/system/.mame
		fi

		mv /usr/bin/mame/*.ini /userdata/system/.mame/

		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g" /userdata/system/BUILD_15KHz//Mame_configs/mame.ini-switchres-generic-32 > /userdata/system/.mame/mame.ini            
		chmod 644 /userdata/system/.mame/mame.ini  
		cp /userdata/system/BUILD_15KHz//Mame_configs/ui.ini-switchres            /userdata/system/.mame/ui.ini 
		chmod 644 /userdata/system/.mame/ui.ini 

		;;
	v33)	
		if [ ! -d "/userdata/system/configs/mame" ]; then                                                              

          		mkdir /userdata/system/configs/mame
	  		mkdir /userdata/system/configs/mame/ini

  		elif [ ! -d "/userdata/system/configs/mame/ini" ]; then
	
	  		mkdir /userdata/system/configs/mame/ini
		fi

		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/ini

		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g" /userdata/system/BUILD_15KHz//Mame_configs/mame.ini-switchres-generic-33 > /userdata/system/configs/mame/ini/mame.ini         		    chmod 644 /userdata/system/configs/mame/ini/mame.ini 
		cp /userdata/system/BUILD_15KHz//Mame_configs/ui.ini-switchres            /userdata/system/configs/mame/ini/ui.ini 
		chmod 644 /userdata/system/configs/mame/ini/ui.ini 

        ;;
	v34)
                                                                                                         
		if [ ! -d "/userdata/system/configs/mame" ]; then                                                              

          		mkdir /userdata/system/configs/mame
	  		mkdir /userdata/system/configs/mame/ini

  		elif [ ! -d "/userdata/system/configs/mame/ini" ]; then
	
	  		mkdir /userdata/system/configs/mame/ini
		fi

		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/

		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g" /userdata/system/BUILD_15KHz//Mame_configs/mame.ini-switchres-generic-v34 > /userdata/system/configs/mame/mame.ini 
		chmod 644 /userdata/system/configs/mame/mame.ini 
		cp /userdata/system/BUILD_15KHz/Mame_configs/ui.ini-switchres            /userdata/system/configs/mame/ui.ini  
		chmod 644 /userdata/system/configs/mame/ui.ini 
	;;
	v35)
                                                                                                         
		if [ ! -d "/userdata/system/configs/mame" ];then                                                              

          		mkdir /userdata/system/configs/mame
	  		mkdir /userdata/system/configs/mame/ini

  		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
	
	  		mkdir /userdata/system/configs/mame/ini
		fi

		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/

		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g" /userdata/system/BUILD_15KHz//Mame_configs/mame.ini-switchres-generic-v35 > /userdata/system/configs/mame/mame.ini 
		chmod 644 /userdata/system/configs/mame/mame.ini 
		cp /userdata/system/BUILD_15KHz/Mame_configs/ui.ini-switchres            /userdata/system/configs/mame/ui.ini  
		chmod 644 /userdata/system/configs/mame/ui.ini 
	;;
	v36)
                                                                                                         
		if [ ! -d "/userdata/system/configs/mame" ];then                                                              

          		mkdir /userdata/system/configs/mame
	  		mkdir /userdata/system/configs/mame/ini

  		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
	
	  		mkdir /userdata/system/configs/mame/ini
		fi

		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/

		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g" /userdata/system/BUILD_15KHz//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini 
		chmod 644 /userdata/system/configs/mame/mame.ini 
		cp /userdata/system/BUILD_15KHz/Mame_configs/ui.ini-switchres            /userdata/system/configs/mame/ui.ini  
		chmod 644 /userdata/system/configs/mame/ui.ini 
	;;


	*)
	echo "Problem of version"
	;;
esac

#######################################################################################                  
## UPGRADE Mame  Batocera  create an folder for new binary of MAME (GroovyMame)                                                                               
####################################################################################### 
                                                                                                       
if [ ! -d "/userdata/system//mame" ];then                                                              

          mkdir /userdata/system/mame

fi

####################################################################################### 


echo "## Mame configuration parameters" >> /userdata/system/batocera.conf
echo "mame.bezel=none"   	>> /userdata/system/batocera.conf
echo "mame.bezel_stretch=0"	>> /userdata/system/batocera.conf
echo "mame.core=mame"		>> /userdata/system/batocera.conf
echo "mame.emulator=mame"	>> /userdata/system/batocera.conf
echo "mame.bezel.tattoo=0"	>> /userdata/system/batocera.conf
echo "mame.bgfxshaders=None"	>> /userdata/system/batocera.conf
echo "mame.hud=none"		>> /userdata/system/batocera.conf
echo "mame.switchres=1"		>> /userdata/system/batocera.conf

echo "# MAME TATE MODE" >> /userdata/system/batocera.conf  
if [ -d "/userdata/system/configs/mame/ini" ];then

	if [ -f "/userdata/system/configs/mame/ini/horizont.ini" ];then
		rm  /userdata/system/configs/mame/ini/horizont.ini
	fi

	if [ -f "/userdata/system/configs/mame/ini/vertical.ini" ];then
		rm  /userdata/system/configs/mame/ini/vertical.ini
	fi

fi

super_width_vertical=1920
interlace_vertical=0
dotclock_min_vertical=25

super_width_horizont=1920
interlace_horizont=0
dotclock_min_horizont=25

if [ $es_rotation_choice -eq 1 ]; then
	echo "mame.rotation=none" >> /userdata/system/batocera.conf
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				  /userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/vertical_normal.ini > /userdata/system/configs/mame/ini/vertical.ini			
		;;
		Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				  /userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/vertical_clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				 /userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/vertical_counter-clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini		
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	echo "fbneo.video_allow_rotate=auto" >> /userdata/system/batocera.conf
fi

if [ $es_rotation_choice -eq 2 ]; then
	echo "mame.rotation=autoror"  >> /userdata/system/batocera.conf
	case $Rotating_screen in 	
		None)	
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				  /userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/horizont_inverted.ini > /userdata/system/configs/mame/ini/horizont.ini			
		;;
		Clockwise)	
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				  /userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/horizont_clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini		
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
			 	 /userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/horizont_counter-clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		*)
				echo "Problems of rotation_choice"
		;;
	esac
	echo "fbneo.video_allow_rotate=off" >> /userdata/system/batocera.conf
fi

if [ $es_rotation_choice -eq 3 ]; then
	echo "mame.rotation=none" >> /userdata/system/batocera.conf
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/vertical_inverted.ini > /userdata/system/configs/mame/ini/vertical.ini	
		;;
		Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/vertical_clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini			
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
			       	/userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/vertical_counter-clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini      
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
        echo "fbneo.video_allow_rotate=auto" >> /userdata/system/batocera.conf
fi

if [ $es_rotation_choice -eq 4 ]; then
	echo "mame.rotation=autorol" >> /userdata/system/batocera.conf
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/horizont_normal.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
			       	/userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/horizont_clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
			       	/userdata/system/BUILD_15KHz/Mame_configs/Mame_TATE/horizont_counter-clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
			;;
			*)
				echo "Problems of rotation_choice"
			;;
		esac
	echo "fbneo.video_allow_rotate=off" >> /userdata/system/batocera.conf
fi

chmod 755 /userdata/system/batocera.conf 
