# diskpoff-tui

A terminal user interface (TUI) for managing removable disk devices on Linux, built in D using `arsd.terminal`, `lsblk`, and `udisksctl`.

## TODO
- review the code (fully generated from spec.md)

## Features

- **Device Overview**: Displays active disk devices with their device path, name/model, serial number, and count of mounted partitions plus unlocked LUKS (`crypt`) containers.
- **Safe Unmount & Lock**: Unmounts all active partitions and locks all encrypted LUKS mappings on the selected disk.
- **Power Off**: Safely powers off drives using `udisksctl power-off`.
- **Status Line**: Visual feedback with animated spinner for ongoing operations and error reporting.

## Keybindings

- **`J` / `Down`**: Move selection down
- **`K` / `Up`**: Move selection up
- **`Enter`**: 
  1. Unmount and lock all partitions/containers on the device (if any are active).
  2. Power off the device (if no partitions/containers are mounted or unlocked).
- **`U`**: Unmount and lock all partitions on the device only.
- **`P`**: Unmount, lock, and power off the device.
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

