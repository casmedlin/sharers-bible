# Sharer's Bible - Windows App

A native Windows Bible reading application built with Go and Fyne.

## Features

- 196 Bible translations across 21 languages
- Offline download and caching
- Multiple themes: Light, Dark, Sepia
- Adjustable font size (14-40px)
- Export passages to Markdown and HTML
- Full localization in 21 languages
- Verse range selection
- Copy passages to clipboard

## Requirements

- Go 1.21+
- Windows 10/11

## Build

### x64
```bash
go mod tidy
set GOARCH=amd64
go build -o sharers-bible-x64.exe
```

### ARM64
```bash
set GOARCH=arm64
go build -o sharers-bible-arm64.exe
```

Package as Windows installer:
```bash
fyne package -os windows -icon icon.png
```

## Run

```bash
go run .
# or
sharers-bible.exe
```

## Configuration

Settings are saved to `%APPDATA%/sharers-bible/`.
Downloaded Bibles are cached in `%APPDATA%/sharers-bible/bibles/`.
