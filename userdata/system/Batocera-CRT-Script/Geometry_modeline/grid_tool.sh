#!/bin/bash

# Display initial message box with information about using the grid tool
dialog --title "Important Information" \
       --msgbox "The grid tool helps adjust image geometry using the CRT service menu. \
Only when you’ve made the best possible adjustments with the grid tool should you use the geometry tool.\n\n\
Always write down your default service menu values, save them on your phone, stick a note on the back of your TV, \
or keep them somewhere safe. Just don’t lose them. Preserving these values gives you more CRT range adjustments. \
If you push the CRT range too far in the geometry tool, you’ll have limited options for in-game adjustments later." 15 70

# Infinite loop for resolution selection dialog
while true; do
    choice=$(dialog --title "Resolution Selection" \
                    --clear \
                    --nocancel \
                    --menu "Choose your resolution" 20 80 10 \
                    "640x480@60" "640x480 60Hz (Default Recommended)" \
                    "320x240@60" "320x240 60Hz" \
                    "Quit" "Exit back to terminal" \
                    3>&1 1>&2 2>&3)

    case $choice in
        "640x480@60")
            switchres 640 480 60 -i switchres.ini -s -l grid
            ;;
        "320x240@60")
            switchres 320 240 60 -i switchres.ini -s -l grid
            ;;
        "Quit")
            clear
            echo "Exit"
            break
            ;;
    esac
done
