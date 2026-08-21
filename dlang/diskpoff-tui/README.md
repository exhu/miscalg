# diskpoff-tui

A terminal user interface (TUI) for managing removable disk devices on Linux, built in D using `arsd.terminal`, `lsblk`, and `udisksctl`.

## TODO
- review the code (fully generated from spec.md)

## Features

- **Device Overview & Tree Expansion**: Displays active disk devices with their device path, name/model, serial number, and count of mounted partitions plus unlocked LUKS (`crypt`) containers. Expanding a device displays its partition hierarchy in a tree-like view.
- **Partition Management**: Supports unmounting and locking individual partitions or all partitions on a selected device.
- **Safe Power Off**: Safely unmounts/locks all device partitions and powers off drives using `udisksctl power-off` (whether the device or an individual partition is selected).
- **Status Line**: Visual feedback with animated spinner for ongoing operations and error reporting.

## Keybindings

- **`J` / `Down`**: Move selection down.
- **`K` / `Up`**: Move selection up.
- **`Enter`**: When a device is selected, toggles the view (expands or collapses the list with this device's partitions).
- **`U`**: Unmount and lock all partitions on the selected device, or only the selected partition.
- **`P`**: Unmount and lock all partitions on the device and power off the device (even when an individual partition is selected).
- **`R`**: Refresh device list.
- **`Q` / `Esc`**: Quit application.

## Build and Run

```bash
dub build
./diskpoff-tui
```

To run unit tests:
```bash
dub test
```

## License

MIT

