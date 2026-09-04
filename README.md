# Studio Display Auto Brightness

An Omarchy bar widget and singleton service that adjusts Apple display
brightness from its ambient-light sensors.

Verified on an Apple display reported by Hyprland as `Studio XDR`.
The same hardware interfaces may make it work with other Apple displays, but
those still need testing.

The higher-numbered Apple HID ALS defaults to Front. The panel can switch to
Back, pause control, and select Dim, Balanced, or Bright preferences. A manual
brightness adjustment pauses automatic control until it is resumed in the
panel.

## Install

```sh
omarchy plugin add https://github.com/miharekar/omarchy-studio-display-auto-brightness.git --enable
```

The controller is a Bash script and only uses commands included with Omarchy:
`hyprctl`, `jq`, `awk`, and `omarchy-brightness-display`. It creates no
systemd units and requires no Python or compiled-language runtime.

## License

MIT
