#!/bin/bash

# Toggle_debug function between true and false
toggle_debug() {
    if $debug_mode; then
        debug_mode=false
        dialog --msgbox "Debug mode turned OFF" 8 40
        set +xv  # Turn off debug mode
    else
        debug_mode=true
        dialog --msgbox "Debug mode turned ON\n\nLog file will be saved to\n/userdata/system/logs/es_tool.log" 8 40
        set -xv  # Turn on debug mode
    fi
}

debug_mode=false
es_arg_file="/userdata/system/es.arg.override"
log_file="/userdata/system/logs/es_tool.log"

# Function to log messages
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$log_file" 2>&1
}

while true; do
    log "Entering main menu loop"
    choice=$(dialog --title  "Custom ES Centering" \
                    --clear \
                    --nocancel \
                    --menu  "Edit custom.es.arg.override\nSee script wiki page for more detail" 150 100 4 \
                    "Custom Es Arg Override"  "Edit Values" \
                    "es.arg.override" "Restore back to default" \
                    "Toggle Debug Mode" "Turn debug mode on/off" \
                    "Exit"  "Exit back to ES without restarting es" 3>&1 1>&2 2>&3)
    
    if ! $debug_mode; then
        clear  # Clear the screen only if debug mode is disabled
    fi

    log "User choice in main menu: $choice"

    case $choice in
        "Custom Es Arg Override")
            log "Entering custom es arg override submenu"
            while true; do
                log "Entering edit values submenu"
                current_horizontal=$(grep "screenoffset_x" "$es_arg_file" | awk '{print $2}')
                current_vertical=$(grep "screenoffset_y" "$es_arg_file" | awk '{print $2}')
                current_horizontal_size=$(grep "screensizeoffset_x" "$es_arg_file" | awk '{print $2}')
                current_vertical_size=$(grep "screensizeoffset_y" "$es_arg_file" | awk '{print $2}')

                edited_value=$(dialog --title "Edit Values" \
                                    --clear \
                                    --menu "Choose a value to edit" 20 50 4 \
                                    "Horizontal Position" "$current_horizontal" \
                                    "Vertical Position" "$current_vertical" \
                                    "Horizontal Size" "$current_horizontal_size" \
                                    "Vertical Size" "$current_vertical_size" \
                                    "Back" "Go back to main menu" 3>&1 1>&2 2>&3)

                log "User choice in edit values submenu: $edited_value"

                if [ "$edited_value" == "Back" ]; then
                    break
                fi

                if [ "$edited_value" == "Horizontal Position" ]; then
                    target="screenoffset_x"
                elif [ "$edited_value" == "Vertical Position" ]; then
                    target="screenoffset_y"
                elif [ "$edited_value" == "Horizontal Size" ]; then
                    target="screensizeoffset_x"
                elif [ "$edited_value" == "Vertical Size" ]; then
                    target="screensizeoffset_y"
                fi

                edited_choice=$(dialog --title "Edit $edited_value" \
                                        --clear \
                                        --menu "Choose new value for $edited_value" 20 50 4 \
                                        "-20" "" \
                                        "-19" "" \
                                        "-18" "" \
                                        "-17" "" \
                                        "-16" "" \
                                        "-15" "" \
                                        "-14" "" \
                                        "-13" "" \
                                        "-12" "" \
                                        "-11" "" \
                                        "-10" "" \
                                        "-09" "" \
                                        "-08" "" \
                                        "-07" "" \
                                        "-06" "" \
                                        "-05" "" \
                                        "-04" "" \
                                        "-03" "" \
                                        "-02" "" \
                                        "-01" "" \
                                        "+01" "" \
                                        "+02" "" \
                                        "+03" "" \
                                        "+04" "" \
                                        "+05" "" \
                                        "+06" "" \
                                        "+07" "" \
                                        "+08" "" \
                                        "+09" "" \
                                        "+10" "" \
                                        "+11" "" \
                                        "+12" "" \
                                        "+13" "" \
                                        "+14" "" \
                                        "+15" "" \
                                        "+16" "" \
                                        "+17" "" \
                                        "+18" "" \
                                        "+19" "" \
                                        "+20" "" 3>&1 1>&2 2>&3)

                log "Edited choice: $edited_choice"

                # Calculate the new value based on the user's selection
                if [[ "$edited_choice" =~ ^[-+][0-9]+$ ]]; then
                    current_value=$(grep "$target" "$es_arg_file" | awk '{print $2}')
                    log "Current value: $current_value"
                    # Extract the sign and value from the edited choice
                    sign=${edited_choice:0:1}
                    value=${edited_choice:1}
                    log "Sign: $sign, Value: $value"
                    # Remove leading zeros from value
                    value=${value#0}
                    # Calculate the new value
                    if [ "$sign" == "+" ]; then
                        # Use arithmetic expansion to perform addition
                        new_value=$((current_value + value))
                    elif [ "$sign" == "-" ]; then
                        # Use arithmetic expansion to perform subtraction
                        new_value=$((current_value - value))
                    fi
                    log "New value: $new_value"

                    # Check if the new value exceeds 99 or -99
                    if (( new_value > 99 )) || (( new_value < -99 )); then
                        dialog --msgbox "The value is too great. It cannot exceed 99 or -99." 8 40
                    else
                        sed -i "s/$target .*/$target $(printf "%02d" "$new_value")/" "$es_arg_file"
                        log "Updated $target to $new_value in $es_arg_file"
                    fi
                else
                    new_value=$edited_choice
                    log "No calculation needed. Edited choice is not in the correct format."
                fi
            done
            ;;
        "es.arg.override")
            log "Restoring es.arg.override to default"
            # Restore back to default
            echo "screenoffset_x 00" > "$es_arg_file"
            echo "screenoffset_y 00" >> "$es_arg_file"
            echo "screensizeoffset_x 00" >> "$es_arg_file"
            echo "screensizeoffset_y 00" >> "$es_arg_file"
            dialog --msgbox "Values restored to default." 8 40
            ;;
        "Toggle Debug Mode")
            toggle_debug
            ;;
		"Exit")
			log "Exiting script without restarting ES"
			# Show a dialog box before exiting
			dialog --msgbox "Please Hold LEFTALT+F1 when you are BACK in EmulationStation to apply the changes.\n\nPRESS OK FIRST TO EXIT!!!" 10 50
			clear
			exit
			;;
        *)
            log "Invalid option: $choice"
            echo "Invalid option"
            ;;
    esac
done

