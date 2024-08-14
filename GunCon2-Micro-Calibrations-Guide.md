**GunCon2 Micro-Calibrations Guide**


Micro Calibrations in-game

Button C + D-pad left/right → decrease x-min → apply if your gun is out on left of the screen

Button C + D-pad up/down → increase x-max → apply if your gun is out on right of the screen


The GunCon2 Micro-Calibrations will reset on reboot and is also not the same for every resolution.
So let's solve that

When you have calibrated a core/emulator/application with micro calibrations do the following

SSH

`evtest`

Choose

`Namco GunCon 2`

Look at value 

`    Event code 3 (ABS_RX)`

`      Value      0`

`      Min      135`

`      Max      735`

Write the last two values down

min = `-m 135`

max = `-M 735`

Now lets edit 
`/userdata/system/scripts/1_GunCon2.sh`

In this example we are editing Nestopia under 

**## Nintendo NES ##**

`#if [[ "$4" == "nestopia" ]]; then evdev-joystick --e /dev/input/by-id/usb-0b9a_016a-event-mouse -m 122 -M 730 -a 3 -f 0; fi`

Remove the `#` then replace them with your values.

`if [[ "$4" == "nestopia" ]]; then evdev-joystick --e /dev/input/by-id/usb-0b9a_016a-event-mouse -m 135 -M 735 -a 3 -f 0; fi`

Save the file

These values are now saved and will be applied next time you start the emulator.
