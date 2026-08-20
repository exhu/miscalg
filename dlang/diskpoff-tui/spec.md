# removable disks management tui

## Overview
Uses lsblk and udisksctl to list and manage devices. Displays a list of active
disk devices. Each line of the list displays device path, name, serial (if
possible) and a number of mounted plus unlocked (crypt) partitions.

User selects using keys the item from the list to either unmount/lock all partitions
on that device, or unmount/lock and power-off the device. All errors are reported.

## Navigation
J/DOWN, K/UP -- move selection down or up
ENTER -- two functions: 1) unmount/lock all devices' partitions; 2) if there're no locked/mounted then poweroff.
U -- only unmount/lock all devices' partitions.
P -- unmount/lock all devices' partitions and poweroff the device.

## TUI display
Use arsd.terminal dub package to draw TUI. ascii pseudographics are used to draw a frame over the list.
Full screen is dark blue, text and frame are white, current selection is inverted.
At the bottom of the screen there's a status line: yellow text on green background in case of success
or pending status. Red background and white text in case of error message.

## TUI behaviour
Display a busy animation in the status line when launching lsblk or udiskctl
