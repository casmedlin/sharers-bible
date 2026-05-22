# 📖 Sharer's Bible

A multi-platform Bible application designed for sharing and study. Contains native macOS, iOS, web, and self-hosted server versions.

## 📂 Project Structure

- **Sharer's Bible App** — Native macOS app (SwiftUI, single-file). Features 196 Bible versions via API, with KJV + ESV bundled offline. Full localization in 21 languages, download manager, and export to JSON/CSV/Markdown/HTML/plain text.
- **Sharers Bible iOS** — Native iOS app for iPhone and iPad.
- **Sharers Bible Web** — Modern web version built with React + TypeScript + Vite. PWA-ready with responsive UI.
- **Sharers Bible TrueNAS** — Self-hosted version for TrueNAS/Docker environments.

## 🚀 macOS App Quick Start

```bash
cd "Sharer's Bible App"
xcrun swiftc -sdk $(xcrun --sdk macosx --show-sdk-path) -parse-as-library \
  -o "build/Sharer's Bible App.app/Contents/MacOS/Sharer's Bible App" \
  -Xlinker -rpath -Xlinker /usr/lib/swift ContentView.swift
```

The app is a single Swift file (`ContentView.swift`, ~4000 lines) compiled directly with `swiftc`. No Xcode project, Swift Package Manager, or CocoaPods needed.

### Data Sources
- **Bundled offline**: KJV + ESV (`bibles/en/kjv.json`, `bibles/en/esv.json`)
- **On-demand API**: 194 additional versions from `https://apibible.wbem.org/api` (free, no auth, no rate limits)
- **Download manager**: Pick a language and download all versions for offline use — stored in `~/Library/Application Support/Sharer's Bible/bibles/`

### Features
- Book/chapter/verse navigation with verse-range picker
- 21 languages for UI and book names (localized via embedded dictionaries)
- 196 Bible versions in 80+ languages
- Themes: Light, Dark, Sepia, System
- Share menu: Copy text, Copy as JSON, Copy as CSV, Export to Markdown, Export to plain text, Export to HTML (theme-colored)
- Settings: Language, theme, font size, download manager

## 📱 iOS Version
Native Apple experience for iPhone and iPad with a smooth reading and sharing interface.

## 🌐 Web Version
Built with **React + TypeScript + Vite**. PWA-capable with responsive design.

## 🐳 TrueNAS / Docker
Containerized deployment for personal home servers via `docker-compose`.

## 🛠 Tech Stack
- **Desktop**: SwiftUI (macOS 14+), compiled with `swiftc`
- **Mobile**: SwiftUI (iOS)
- **Web**: React, TypeScript, Vite
- **Deployment**: Docker, TrueNAS

## 📝 License
Proprietary / Private project by casmedlin.
