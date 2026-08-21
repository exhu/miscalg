# removable disks management tui

## Overview
Uses lsblk and udisksctl to list and manage devices. Displays a list of active
disk devices. Each line of the list displays device path, name, serial (if
possible) and a number of mounted plus unlocked (crypt) partitions.

When selecting the device with the ENTER key the list is expanded with it's partitions. So that each partition can be
unmounted separately.

User selects using keys the item from the list to either unmount/lock all partitions
on that device, or unmount/lock and power-off the device. All errors are reported.

## Navigation
J/DOWN, K/UP -- move selection down or up
ENTER -- when device is selected toggles the view: expands or collapses the list with this devices' partitions.
U -- only unmount/lock all devices' partitions or a selected partition.
P -- unmount/lock all devices' partitions and poweroff the device (even when individual partition of the device is selected).

## TUI display
Use arsd.terminal dub package to draw TUI. ascii pseudographics are used to
draw a frame over the list.  Full screen is dark blue, text and frame are
white, current selection is inverted.  At the bottom of the screen there's a
status line: yellow text on green background in case of success or pending
status. Red background and white text in case of error message.

Initially the list contains only devices, when a device is expanded it's
displayed in a tree-like fashion with partitions of the device as leaves.

## TUI behaviour
Display a busy animation in the status line when launching lsblk or udiskctl
