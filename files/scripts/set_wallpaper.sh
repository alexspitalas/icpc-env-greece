#!/bin/bash

# Set the wallpaper for every channel in xfce4-desktop
xres=($(echo $(xfconf-query --channel xfce4-desktop --list | grep last-image)))

for x in "${xres[@]}"

do
    xfconf-query --channel xfce4-desktop --property $x --set "/icpc/wallpaper.png"
done