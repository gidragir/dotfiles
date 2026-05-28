#!/usr/bin/env bash

chosen=$(cliphist list | rofi -dmenu -theme ~/.config/rofi/cliphist.rasi -p "")

[ -z "$chosen" ] && exit

cliphist decode <<< "$chosen" | wl-copy
sleep 0.1 && wtype -M ctrl v
