# Omarchy Themed File Manager

An [Omarchy](https://omarchy.org/) shell plugin that reskins GTK Files
(Nautilus) — and other libadwaita apps — to match the current Omarchy shell
theme. **Visual only: no functionality of any app is touched.**

## What it does

On startup and on every Omarchy theme change the plugin:

1. Reads the Omarchy palette from the current theme's `colors.toml`
   (`~/.local/state/omarchy/current/theme/`).
2. Writes `~/.config/gtk-4.0/gtk.css`, overriding libadwaita's named colors
   (`@define-color` + `:root` CSS variables): window, view, sidebar, dialog,
   popover, card, headerbar, thumbnail, border, and accent roles.
3. Never interrupts running apps: a running Nautilus keeps its current theme
   and picks up the new CSS the next time it (or any other GTK4 app) is
   launched. The `--restart-nautilus` flag on the apply script forces an
   immediate clean dbus re-theme if you ever want it.

## Scope

GTK reads `~/.config/gtk-4.0/gtk.css` for **all** GTK4/libadwaita apps, so
the reskin is intentionally global: Files, gedit, gnome-calculator, and other
libadwaita apps all match the Omarchy theme. Hand edits to
`~/.config/gtk-4.0/gtk.css` are overwritten on every apply.

## Theme change detection

`omarchy-theme-set` swaps the whole `current/theme` directory (`rm -rf` +
`mv`), which can defeat inode-based file watches. Detection is layered:

- `FileView.watchChanges` on `colors.toml` and `theme.name`
- `Connections` hooks on the shell's `Color` singleton (the shell pushes the
  new palette over IPC on runtime theme switches)
- a 10-second poll of `theme.name` as a backstop

Rapid theme swaps are debounced (700 ms) into a single apply.

## Install

```bash
omarchy plugin add https://github.com/YOUR_USERNAME/omarchy-themed-files.git --enable
```

From a local checkout:

```bash
omarchy plugin add /path/to/omarchy-themed-files --enable --yes
```

Reload after code changes: files under `~/.config/omarchy/plugins/` hot-reload
on save; force with `omarchy-shell shell rescanPlugins`.

Remove:

```bash
omarchy plugin remove cheapseatsecon.themed-files
```

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Plugin manifest (`service` kind, `keepLoaded`) |
| `Service.qml` | Watches theme changes, runs the apply script |
| `bin/themed-files-apply` | Generates `gtk.css` from the Omarchy palette |
