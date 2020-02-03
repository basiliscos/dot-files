#!/bin/sh

#sudo rmmod psmouse
#sudo modprobe psmouse psmouse.synaptics_intertouch=1

#rmmod hid_multitouch
#modprobe hid_multitouch hid_multitouch.synaptics_intertouch=1

#sleep 2

#DEVICE="SynPS/2 Synaptics TouchPad"
#xinput set-prop "$DEVICE" "Evdev Wheel Emulation" 1
#xinput set-prop "$DEVICE" "Evdev Wheel Emulation Button" 2
#xinput set-prop "$DEVICE" "Evdev Wheel Emulation Timeout" 200

sudo rmmod i2c-hid
sudo modprobe i2c-hid

sleep 2

synclient TouchpadOff=0
synclient TapButton1=1
synclient TapButton2=3
synclient TapButton3=2
synclient PalmDetect=1
synclient VertTwoFingerScroll=1
synclient HorizTwoFingerScroll=1
