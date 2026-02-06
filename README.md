# Contexter

A lightweight macOS app for managing context — project files, notes, and links — in one organized workspace.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift)
[![Release](https://img.shields.io/github/v/release/ViGeng/contexter)](https://github.com/ViGeng/contexter/releases)

## Features

- 📁 **Folder Monitoring** — Automatically syncs with your project directories
- 📝 **Rich Text Blocks** — Create and edit text content within pages
- 🔗 **Link Management** — Organize and access related links
- 🖼️ **File Preview** — Quick Look integration for attached files
- 🌲 **Tree Navigation** — Intuitive sidebar for browsing your context pages

## Installation

### Homebrew (Recommended)

```bash
brew tap ViGeng/tap
brew install --cask contexter
```

### Manual Download

Download the latest `.zip` from [Releases](https://github.com/ViGeng/contexter/releases), extract, and drag `contexter.app` to your Applications folder.

## Usage

1. Launch **Contexter**
2. Your context pages are stored in `~/ContextRoot/`
3. Create new pages, add text blocks, and attach files
4. Use the sidebar to navigate between pages

## Building from Source

```bash
git clone https://github.com/ViGeng/contexter.git
cd contexter
xcodebuild -project contexter.xcodeproj \
  -scheme contexter \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (for building from source)

## License

MIT License - see [LICENSE](LICENSE) for details.
