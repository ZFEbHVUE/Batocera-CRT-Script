# Batocera-CRT-Script v44 - step 14: rotation
# Physical screen rotation and EmulationStation orientation -> per-emulator rotation values.
echo ""; b71; echo "##                          ROTATING SCREEN                          ##"; e71
echo "##       SET THE ACTUAL PHYSICAL ORIENTATION OF YOUR MONITOR         ##"
echo "##         AND THE DIRECTION OF ROTATION (HORIZONTAL ↔ VERTICAL)     ##"; e71
echo "##   If you use your monitor normally (no physical rotation),        ##"
echo "##   select: NONE                                                    ##"; e71
echo "##                           IMPORTANT                               ##"; e71
echo "##   ┌──────────────────────────────┐                                 ##"
echo "##   │        EMULATOR NOTES        │                                 ##"
echo "##   └──────────────────────────────┘                                 ##"; e71
echo "##   ● MAME (GroovyMAME): Works for all horizontal and vertical       ##"
echo "##     games automatically on any screen orientation.                ##"; e71
echo "##   ● FBNeo:                                                        ##"
echo "##       - Horizontal screen → Horizontal games (no rotation)        ##"
echo "##                              Vertical games (rotated)             ##"
echo "##       - Vertical screen   → Horizontal games (rotated)            ##"
echo "##                              Vertical games (no rotation)         ##"; e71
echo "##   ● Libretro cores: Works for all horizontal games.               ##"
echo "##     Some TATE (vertical) modes may have rotation issues.          ##"; e71
echo "##   ● Standalone emulators: Works for horizontal games on           ##"
echo "##     rotated screens. Some vertical modes may show bugs.           ##"; e71
echo "##   ● Future Pinball: Works correctly in both horizontal and         ##"
echo "##     vertical (portrait) display modes.                            ##"; e71
echo "##   These options allow you to play classic horizontal games on     ##"
echo "##   vertical monitors — with or without rotation — across           ##"
echo "##   various emulators. Remember: by default, emulators run          ##"
echo "##   in horizontal mode (no rotation).                               ##"; e71
echo "##   Only GroovyMAME automatically detects whether a game is         ##"
echo "##   horizontal or vertical and adjusts rotation accordingly.        ##"; e71; b71; echo ""
declare -a Screen_rotating=( "None" "Clockwise" "Counter-Clockwise" )
for var in "${!Screen_rotating[@]}" ; do echo "			$((var+1)) : ${Screen_rotating[$var]}" | tee -a "$CRT_LOG"; done
echo ""; b71; echo "##       Make your choice for the sens of your rotation screen       ##" | tee -a "$CRT_LOG"; b71
pick Screen_rotating_choice $((var+1))
Rotating_screen=${Screen_rotating[$Screen_rotating_choice-1]}
echo -e "                    Your choice is : ${GREEN} $Rotating_screen${NOCOLOR}" | tee -a "$CRT_LOG"; echo ""; b71
echo "##                     EMULATIONSTATION ORIENTATION                  ##"
echo "##                  MONITOR SETUP (FROM HORIZONTAL)                  ##"; e71
echo "##  HORIZONTAL (Default)             →  NORMAL     (0°)              ##"
echo "##  VERTICAL (Counter-Clockwise)     →  TATE90     (90°)             ##"
echo "##  HORIZONTAL (Upside Down)         →  INVERTED   (180°)            ##"
echo "##  VERTICAL (Clockwise)             →  TATE270    (270° or -90°)    ##"; e71; b71; echo ""
declare -a ES_orientation=( "NORMAL" "TATE90" "INVERTED" "TATE270" )
if ([ "$TYPE_OF_CARD" == "NVIDIA" ]&&[ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]); then
	declare -a display_rotation=( "normal" "normal" "normal" "normal" )
	declare -a display_mame_rotation=( "normal" "left" "normal" "right" )
	case $Rotating_screen in
		None)
			declare -a display_libretro_rotation=( "normal" "right" "normal" "right" )
			declare -a display_standalone_rotation=( "normal" "normal" "normal" "normal" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" ) ;;
		Clockwise)
			declare -a display_libretro_rotation=( "normal" "left" "normal" "right")
			declare -a display_standalone_rotation=( "normal" "left" "normal" "left" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" ) ;;
		Counter-Clockwise)
			declare -a display_libretro_rotation=( "normal" "right" "normal" "right" )
			declare -a display_standalone_rotation=( "normal" "right" "normal" "right" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" ) ;;
		*) echo "problems of choice of rotation" ;;
	esac
else
	declare -a display_rotation=( "normal" "right" "inverted" "left" )
	declare -a display_mame_rotation=( "normal" "normal" "inverted" "normal" )
	case $Rotating_screen in
		None)
			declare -a display_libretro_rotation=( "normal" "right" "inverted" "left" )
			declare -a display_standalone_rotation=( "normal" "right" "inverted" "left" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" ) ;;
		Clockwise)
			declare -a display_libretro_rotation=( "normal" "normal" "inverted" "inverted" )
			declare -a display_standalone_rotation=( "normal" "normal" "inverted" "inverted" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" ) ;;
		Counter-Clockwise)
			declare -a display_libretro_rotation=( "normal" "inverted" "inverted" "normal" )
			declare -a display_standalone_rotation=( "normal" "inverted" "inverted" "normal" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" ) ;;
		*) echo "problems of choice of rotation" ;;
	esac
fi
for var in "${!ES_orientation[@]}" ; do echo "			$((var+1)) : ${ES_orientation[$var]}" | tee -a "$CRT_LOG"; done
echo ""; b71; echo "##              Select your EmulationStation orientation             ##"
echo "##        (Choose the position that matches your monitor setup)      ##"; b71
pick es_rotation_choice $((var+1))
ES_rotation=${ES_orientation[$es_rotation_choice-1]}; display_rotate=${display_rotation[$es_rotation_choice-1]}
display_mame_rotate=${display_mame_rotation[$es_rotation_choice-1]}
display_libretro_rotate=${display_libretro_rotation[$es_rotation_choice-1]}
display_standalone_rotate=${display_standalone_rotation[$es_rotation_choice-1]}
display_fbneo_rotate=${display_fbneo_rotation[$es_rotation_choice-1]}
echo -e "                    Your choice is :  ${GREEN}$ES_rotation${NOCOLOR}" | tee -a "$CRT_LOG"
