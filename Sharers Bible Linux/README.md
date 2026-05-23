# Sharer's Bible - Linux App

A native Linux Bible reading application built with Python and GTK4 (PyGObject).

## Features

- 196 Bible translations across 21 languages
- Offline download and caching
- Multiple themes: Light, Dark, Sepia, System
- Adjustable font size (14-40px)
- Export passages to Markdown and HTML
- Full localization in 21 languages
- Verse range selection
- Copy passages to clipboard

## Requirements

```bash
pip install -r requirements.txt
```

On Debian/Ubuntu:
```bash
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-4.0
```

On Fedora:
```bash
sudo dnf install python3-gobject gtk4
```

## Run

```bash
make run
# or
python3 main.py
```

## Build Flatpak

```bash
make flatpak
```

Flatpak builds for whatever architecture you're on (x86_64 or aarch64). The GNOME runtime supports both.

## Build Snap

```bash
make snap
```

Snapcraft builds for the current architecture by default. For cross-arch builds:
```bash
snapcraft --target-arch=arm64
```

## Architecture Support

| Arch | Flatpak | Snap |
|------|---------|------|
| x86_64 | ✓ | ✓ |
| ARM64 (aarch64) | ✓ | ✓ |

Python/GTK4 is arch-independent — the native libraries come from the platform runtime.

## Configuration

Settings are saved to `~/.config/sharers-bible/config.ini`.
Downloaded Bibles are cached in `~/.local/share/sharers-bible/bibles/`.
