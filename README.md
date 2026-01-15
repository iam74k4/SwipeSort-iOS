<<<<<<< HEAD
# SwipeSort-iOS
=======
# SwipeSort-iOS

![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-iOS%2018.0+-orange?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-@Observable-007AFF?style=flat-square&logo=swift&logoColor=white)

[English](./README.md) | [日本語](./README.ja.md)

A photo and video organizer app with intuitive swipe gestures for iOS.

## Overview

SwipeSort allows you to quickly sort photos and videos into "Keep", "Delete", and "Favorites" using intuitive swipe gestures. Built with modern Swift 6 and SwiftUI for a beautiful, performant experience.

## Tech Stack

![iOS](https://img.shields.io/badge/iOS-18.0+-000000?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)
![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-5856D6?style=for-the-badge&logo=apple&logoColor=white)

| Category | Technology |
|----------|------------|
| Language | Swift 6.0 (Strict Concurrency) |
| UI Framework | SwiftUI (@Observable) |
| Architecture | Feature-based |
| Photo Access | Photos.framework |
| Data Persistence | SwiftData |

## Features

### Sorting
- **Swipe Right**: Keep
- **Swipe Left**: Delete immediately (moves to iOS "Recently Deleted")
- **Double Tap**: Add to favorites (syncs with iOS Favorites album ❤️)
- **Long Press**: Play video or Live Photo (while pressing)
- **Undo**: Revert the last action (except delete)

### Media Display
- Full image display (Aspect Fit) - no cropping
- Photo, video, and Live Photo support
- RAW and burst photo support

### Other Features
- Persistent sorting results (SwiftData)
- Progress display (X / Y items)
- Large library support (PHCachingImageManager for prefetching)
- 2-tab interface: Sort / Settings

## Requirements

- iOS 18.0 or later
- iPhone only
- Portrait orientation only

## Installation

1. Clone the repository

```bash
git clone https://github.com/iam74k4/SwipeSort-iOS.git
cd SwipeSort-iOS
```

2. Open `SwipeSort.xcodeproj` in Xcode

3. Configure your development team in Signing & Capabilities

4. Build and run on a device or simulator

## Project Structure

```
SwipeSort-iOS/
├── SwipeSort/
│   ├── App/
│   │   ├── SwipeSortApp.swift      # App entry point
│   │   ├── RootView.swift          # Auth & navigation
│   │   └── AppState.swift          # Global state (@Observable)
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── SortCategory.swift  # Category enum
│   │   │   └── SortRecord.swift    # SwiftData models
│   │   ├── PhotoLibrary/
│   │   │   ├── PhotoAsset.swift    # Asset wrapper
│   │   │   └── PhotoLibraryClient.swift  # Photo access
│   │   └── Storage/
│   │       └── SortResultStore.swift     # SwiftData store
│   ├── Features/
│   │   ├── Sorting/
│   │   │   ├── SortingFeature.swift      # Sorting screen
│   │   │   ├── SortingState.swift        # Sorting state
│   │   │   └── Components/
│   │   │       ├── SwipeOverlay.swift
│   │   │       ├── LivePhotoView.swift
│   │   │       └── VideoPlayerView.swift
│   │   └── Settings/
│   │       └── SettingsFeature.swift     # Settings screen
│   ├── Shared/
│   │   ├── Theme/
│   │   │   └── AppTheme.swift      # Colors, gradients, haptics
│   │   └── Extensions/
│   │       └── DateExtensions.swift
│   ├── Assets.xcassets/
│   └── Info.plist
└── SwipeSort.xcodeproj/
```

## Architecture

- **Feature-based**: Organized by feature, not by layer
- **@Observable**: Modern state management (iOS 17+)
- **SwiftData**: Type-safe persistence
- **Swift 6**: Strict concurrency checking

## Usage

1. Launch the app and grant photo library access
2. Swipe photos left/right to sort, double tap for favorites
3. Long press to preview videos and Live Photos
4. Deleted items go to iOS "Recently Deleted" (recoverable for 30 days)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

iam74k4
>>>>>>> ac74cb9 (feat: Major UI/UX improvements)
