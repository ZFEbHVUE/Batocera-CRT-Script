#!/bin/bash
#
#
#

cp /etc/switchres.ini.bak 			                  /etc/switchres.ini
cp /userdata/system/configs/mame/mame.ini.bak 	  /userdata/system/configs/mame/mame.ini
cp /userdata/system/custom-es-config.bak	        /userdata/system/custom-es-config

MONITOR=$(grep -m 1 "monitor     " /etc/switchres.ini | awk '{print $NF}')

if [[ ! -f /userdata/system/99-nvidia.conf ]]; then

	# AMD/ATI INTEL and Nvidia(NOUVEAU)
	TYPE_OF_CARD="AMD_INTEL_NVIDIA_NOUV"

	if [[ "$MONITOR" == "arcade_15" ]]; then

		RES_GEOM=("648x478 60")
	    	RESOLUTIONS=(	  "640x480 60" "768x576 50" "1280x480 60" "1280x576 50" "1280x240 60" "240x240 60" "256x192 60" \
			       	          "256x200 60" "256x224 50" "256x240 60" "288x224 50" "304x224 50" "320x200 60" "320x224 60" \
			       	          "320x240 60" "320x256 60" "352x240 60" "360x200 60" "360x240 60" "380x284 60" "384x216 60" \
			       	          "384x240 60" "384x480 60" "400x200 60" "400x224 60" "400x240 60" "416x240 60" "426x240 60" \
			       	          "427x240 60" "428x240 60" "432x240 60" "432x244 60" "456x256 60" "460x200 60" "464x272 50" \
			       	          "480x240 60" "480x270 60" "480x272 50" "512x288 50" "512x480 60" "528x288 50" "640x240 60" \
				                "854x480 60" "864x486 60")

	elif [[ "$MONITOR" == "arcade_15ex" ]]; then

		RES_GEOM=("648x478 60")
		RESOLUTIONS=(	  "640x480 60" "768x576 50" "1280x480 60" "1280x576 50" "1280x240 60" "240x240 60" "256x192 60" \
	       			      "256x200 60" "256x224 60" "256x240 60" "288x224 60" "304x224 60" "320x200 60" "320x224 60" \
				            "320x240 60" "320x256 60" "352x240 60" "360x200 60" "360x240 60" "380x284 54" "384x216 60" \
				            "384x240 60" "384x480 60" "400x200 60" "400x224 60" "400x240 60" "416x240 60" "426x240 60" \
		       		      "427x240 60" "428x240 60" "432x240 60" "432x244 60" "456x256 60" "460x200 60" "464x272 56" \
		       		      "480x240 60" "480x270 56" "480x272 56" "512x288 50" "512x480 60" "528x288 50" "640x240 60" \
		       		      "854x480 60" "864x486 60")

	elif [[ "$MONITOR" == "arcade_15_25" ]]; then
	
		RES_GEOM=("648x478 60")
		RESOLUTIONS=( 	"640x480 60" "768x576 50" "1280x480" "1280x576 50" "1280x240" "240x240" "256x192" \
				            "256x200 60" "256x224 60" "256x240 60" "288x224 60" "304x224 60" "320x200 60" "320x224 60" \
		                "320x240 60" "320x256 50" "352x240 60" "360x200 60" "360x240 60" "380x284 50" "384x216 60" \
 				            "384x240 60" "384x480 60" "400x200 60" "400x224 60" "400x240 60" "416x240 60" "426x240 60" \
				            "427x240 60" "428x240 60" "432x240 60" "432x244 60" "456x256 55" "460x200 60" "464x272 50" \
				            "480x240 60" "480x270 50" "480x272 50" "512x288 50" "512x480 60" "528x288 50" "640x240 60" \
				            "854x480 60" "864x486 60")

	elif [[ "$MONITOR" == "arcade_15_25_31" ]]; then
	
		RES_GEOM=("648x478 60")

		RESOLUTIONS=( 	"640x480 60" "768x576 50" "1280x480 60" "1280x576 50" "1280x240 60" "256x192 60" "240x240 60" \
  				          "256x200 60" "256x224 60" "256x240 60" "288x224 60" "304x224 60" "320x200 60" "320x224 60" \
  				          "320x240 60" "320x256 60" "352x240 60" "360x200 60" "360x240 60" "380x284 50" "384x216 60" \
  				          "384x240 60" "384x480 60" "400x200 60" "400x224 60" "400x240 60" "416x240 60" "426x240 60" \
		       		      "427x240 60" "428x240 60" "432x240 60" "432x244 60" "456x256 60" "460x200 60" "464x272 55" \
  				          "480x240 60" "480x270 55" "480x272 55" "512x288 60" "512x480 60" "528x288 50" "640x240 60" \
				            "854x480 60" "864x486 60" )

	elif [[ "$MONITOR" == "generic_15" ]]; then

		RES_GEOM=("648x478 60")
		RESOLUTIONS=(	  "640x480 60" "768x576 50" "1280x480 60" "1280x576 50" "1280x240 60" "240x240 60" "256x192 60" \
			          	  "256x200 60" "256x224 50" "256x240 60" "288x224 50" "304x224 50" "320x200 60" "320x224 60" \
			       	      "320x240 60" "320x256 60" "352x240 60" "360x200 60" "360x240 60" "380x284 60" "384x216 60" \
			       	      "384x240 60" "384x480 60" "400x200 60" "400x224 60" "400x240 60" "416x240 60" "426x240 60" \
			       	      "427x240 60" "428x240 60" "432x240 60" "432x244 60" "456x256 60" "460x200 60" "464x272 50" \
			       	      "480x240 60" "480x270 60" "480x272 50" "512x288 50" "512x480 60" "528x288 50" "640x240 60" \
				            "854x480 60" "864x486 60")

	elif [[ "$MONITOR" == "arcade_25" ]]; then

		RES_GEOM=("648x478 60")
		RESOLUTIONS=( 	"1024x768 60" "496x384 60" "512x384 60" "960x768 60"  "1280x768 60"  "1368x768 60"  )

	elif [[ "$MONITOR" == "arcade_31" ]]; then

		RES_GEOM=("648x478 60")
		RESOLUTIONS=( 	"640x480 60" "854x480 60" "864x486 60" )

	else
		echo "problems in your monitor definition"
	fi

else
	#### NVIDIA (NVIDIA-DRIVERS)
	if [[ "$MONITOR" == "arcade_25" ]]; then

      		RES_GEOM=("648x478 60")
		RESOLUTIONS=( 	"384x480" "640x480" "640x480" "720x480" "800x600" "1024x576"  "1280x576"  "854x480" "864x486")

	elif [[ "$MONITOR" == "arcade_31" ]]; then

		RES_GEOM=("648x478 60")
		RESOLUTIONS=( 	"384x480" "640x480" "640x480" "720x480" "800x600" "1024x576"  "1280x576"  "854x480" "864x486")

	else
		RES_GEOM=("648x478 60")
		RESOLUTIONS=( "3600x480 60" "1920x240 60" "1920x256 50" "1920x480 60" "2560x256 60" "2560x448 60" "1280x480 60" \
		     		      "1024x600 50" "768x576 50"  "854x480 60" "864x486 60"  "800x600 50" "720x480 60" "640x480 60")
	fi
 
fi

#### FORCED DOTCLOCK_MIN TO 0 TO USE SWITCHRES 
DOTCLOCK_MIN=$(grep -v "^#" /etc/switchres.ini | grep "dotclock_min" | head -1 | awk '{print $2}')
DOTCLOCK_MIN_SWITCHRES=0
sed -i "s/.*dotclock_min        .*/        dotclock_min              $DOTCLOCK_MIN_SWITCHRES/"  /etc/switchres.ini

###############################################################################################################
#
#
#
RES_TOT_GEOM=$(echo $RES_GEOM | sed 's/x/ /')
DISPLAY=:0 geometry  $RES_TOT_GEOM	>/userdata/roms/ports/crt.txt
sed -i 's/Final crt_range:/crt_range0               /g' 	/userdata/roms/ports/crt.txt
sed -i '1,2d' /userdata/roms/ports/crt.txt
sed -i 's/.*monitor         .*/monitor                   custom/'  	 /userdata/system/configs/mame/mame.ini
sed -i '/Final geometry/d' /userdata/roms/ports/crt.txt
CRT_0="$(cat /userdata/roms/ports/crt.txt)"
sed -i "s/^crt_range0.*/$CRT_0/"  /userdata/system/configs/mame/mame.ini
sed -i 's/.*monitor         .*/        monitor                   custom/' 	/etc/switchres.ini
sed -i '/Final geometry/d' /userdata/roms/ports/crt.txt
sed -i 's/crt_range0/        crt_range0/g' 					/userdata/roms/ports/crt.txt
sed -i "s/.*crt_range0   .*/        $CRT_0/"  					/etc/switchres.ini
###############################################################################################################

for RES in "${RESOLUTIONS[@]}"
do
	RESOLUTION_TOT=$(echo $RES | sed 's/x/ /')
	RESOLUTION=$(echo $RES | cut -d' ' -f1)
    	FREQUENCY=$(echo $RES | cut -d' ' -f2)
	FORCED_RESOLUTION="$RESOLUTION@$FREQUENCY"

    	switchres $RESOLUTION_TOT -f $FORCED_RESOLUTION -m custom -c >/userdata/roms/ports/mode.txt
	sed -i '/Calculating best video mode/d' /userdata/roms/ports/mode.txt	
    	sed -i 's/^.*"//' /userdata/roms/ports/mode.txt
	if [[ "$TYPE_OF_CARD" == "AMD_INTEL_NVIDIA_NOUV" ]]; then
		sed -i 's|^|xrandr -display :0.0 --newmode "'"$RESOLUTION"'" |' /userdata/roms/ports/mode.txt
	else
		sed -i 's|^|"'"$RESOLUTION"'" |' /userdata/roms/ports/mode.txt
	fi
  	TERM="$RESOLUTION"
  	MODE_CONTENT="$(cat /userdata/roms/ports/mode.txt)"
	if [[ "$TYPE_OF_CARD" == "AMD_INTEL_NVIDIA_NOUV" ]]; then
		sed -i '/^#/!s/xrandr -display :0\.0 --newmode "'"$TERM"'" .*/'"$MODE_CONTENT"'/' /userdata/system/custom-es-config
	else
		sed -i "/\"$TERM\"/c\\       Modeline $MODE_CONTENT" /userdata/system/99-nvidia.conf
	fi
    	sed -i '1d' /userdata/roms/ports/mode.txt
done
mv /userdata/roms/ports/crt.txt /userdata/roms/ports/crt_range_0_mod.log
rm /userdata/roms/ports/mode.txt

### PUT THE GOOD DOTCLOCK_MIN IN SWITCHRES.INI
sed -i "s/.*dotclock_min        .*/        dotclock_min              $DOTCLOCK_MIN/"  /etc/switchres.ini

batocera-save-overlay
#reboot
