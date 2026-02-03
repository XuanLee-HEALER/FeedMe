# FeedMe

A lightweight macOS menu bar RSS reader.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu Bar Native** - Lives in your menu bar, minimal distraction
- **Left Click** - Quick access to latest articles
- **Right Click** - App settings and feed management
- **Smart Refresh** - Automatic background refresh with ETag/Last-Modified support
- **OPML Support** - Import/Export your subscriptions
- **Native macOS** - Built with SwiftUI and AppKit

## Screenshots

<!-- TODO: Add screenshots -->

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)

## Installation

### Download

Download the latest release from [Releases](https://github.com/XuanLee-HEALER/FeedMe/releases).

### Build from Source

```bash
git clone https://github.com/XuanLee-HEALER/FeedMe.git
cd FeedMe
xcodebuild -project FeedMe.xcodeproj -scheme FeedMe -configuration Release build
```

## Usage

1. **Add Feed** - Right-click the menu bar icon → "Manage Subscriptions" → Click "+"
2. **Read Articles** - Left-click the menu bar icon to see latest articles
3. **Open Article** - Click any article to open in your default browser
4. **Mark as Read** - Articles are automatically marked as read when opened
5. **Refresh** - Click "Refresh" or wait for automatic refresh

## Tech Stack

- **UI**: SwiftUI + AppKit (NSStatusItem, NSMenu)
- **Storage**: SQLite via GRDB.swift
- **Feed Parsing**: FeedKit
- **Network**: URLSession with ETag/Last-Modified caching

## Project Structure

```
FeedMe/
├── FeedMe/
│   ├── FeedMeApp.swift       # App entry point
│   ├── AppDelegate.swift     # Menu bar logic
│   ├── ContentView.swift     # Settings view
│   ├── Models/               # Data models
│   ├── Services/             # Business logic
│   ├── Views/                # SwiftUI views
│   └── Managers/             # Singletons
├── FeedMeTests/              # Unit tests
└── FeedMeUITests/            # UI tests
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [FeedKit](https://github.com/nmdias/FeedKit) - RSS/Atom feed parser
- [GRDB.swift](https://github.com/groue/GRDB.swift) - SQLite toolkit
