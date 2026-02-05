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
- **Swipe Left**: Add to delete queue (batch delete with "X items delete" button)
- **Double Tap**: Add to favorites (syncs with iOS Favorites album ❤️)
- **Long Press**: Play video or Live Photo (while pressing)
- **Undo**: Revert the last action (can also remove from delete queue)
- **Filter**: Filter by photos, videos, Live Photos, screenshots
- **Category Filter**: Tap the stat pills (Keep/Delete/Favorite) in the top bar to show only that category
- **Album Creation**: Force press on Keep or Favorite stat pills to add photos to albums

### Media Display
- Full image display (Aspect Fit) - no cropping
- Photo, video, and Live Photo support
- RAW and burst photo support
- Creation date display (relative time)

### Other Features
- Persistent sorting results (SwiftData)
- Progress display (X / Y items)
- Statistics display (real-time count of Keep/Delete/Favorite)
- Large library support (PHCachingImageManager for prefetching)
- 2-tab interface: Sort / Settings
- Tip Jar: Support the developer with optional in-app purchases (StoreKit 2)
- Settings screen with statistics, gesture guide, haptic feedback toggle, and support links
- Album creation: Add sorted photos to iOS albums via drag and drop

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

## Configuration

Support and external links are read from `SwipeSort/Info.plist`. Edit these keys to customize for your build:

- **SwipeSortSupportEmail**: Feedback mail address (mailto:). If missing or empty, the app shows "Email Not Configured" in Settings.
- **SwipeSortDiscordURL**: Discord invite URL.
- **SwipeSortAppStoreID**: App Store ID (used for the review link).
- **SwipeSortPrivacyPolicyURL**: Privacy policy URL.

You can leave placeholder values in the repo and inject real values at build time (e.g. via xcconfig or CI) if you prefer not to commit them.

## Branch Policy & Workflow

- **develop**: Default development branch. Use for daily commits and pull requests.
- **main**: Release-only branch. Update only when releasing (merge from develop, then push a version tag). Do not push feature work directly to main.

**Recommended workflow:** Develop on `develop` → when releasing: merge `develop` into `main`, push a `v*` tag from `main` → CI runs on both branches; Release and TestFlight run on tag push. See [.github/WORKFLOWS.md](.github/WORKFLOWS.md) for the step-by-step flow.

## Version Management

This project uses **automatic version management** based on Git tags. The version is automatically set during build time - you don't need to manually update version numbers.

### How It Works

- **Main branch**: Uses the version from the latest Git tag (e.g., `v1.0.0` → `1.0.0`)
- **Develop branch**: Uses the next patch version (e.g., `v1.0.0` → `1.0.1`)
- **Build number (Local/CI)**: Calculated from the number of commits since the latest tag
- **Build number (TestFlight)**: Uses `github.run_number` for automatic increment (prevents duplicate version errors)

### Creating Version Tags

To create a new version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The tag format should follow Semantic Versioning: `vX.Y.Z` (e.g., `v1.0.0`, `v1.1.0`, `v2.0.0`)

### Automatic Version Setting

- **Local builds**: The version script automatically updates `project.pbxproj` during build (changes are not committed to Git)
- **CI/CD**: The version script is automatically used in GitHub Actions workflows
- **No manual steps required**: Just build the project, and the version will be set automatically

### Troubleshooting

- **No tags found**: The script will use default values (`0.0.1` for main, `0.0.2` for develop)
- **Not in a Git repository**: The script will use default values and continue the build
- **Build number increases**: Each commit increases the build number automatically

### Note

The `project.pbxproj` file may show as modified after building, but **you don't need to commit these changes**. The version is updated only during build time.

## Project Structure

```
SwipeSort-iOS/
├── .github/
│   ├── WORKFLOWS.md                # Workflow documentation
│   └── workflows/
│       ├── ci.yml                  # Build & test
│       ├── release.yml             # GitHub Release
│       └── testflight.yml          # TestFlight upload
├── scripts/
│   └── version.sh                  # Auto version management
├── LICENSE                         # MIT License
├── README.md
├── README.ja.md
├── SwipeSort/
│   ├── App/
│   │   ├── SwipeSortApp.swift      # App entry point
│   │   ├── RootView.swift          # Photo access state and tab navigation
│   │   └── AppState.swift          # Global state (@Observable)
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── SortCategory.swift  # Category enum
│   │   │   └── SortRecord.swift    # SwiftData models
│   │   ├── PhotoLibrary/
│   │   │   ├── PhotoAsset.swift    # Asset wrapper
│   │   │   └── PhotoLibraryClient.swift  # Photo access
│   │   ├── Storage/
│   │   │   └── SortResultStore.swift     # SwiftData store
│   │   └── Store/
│   │       └── TipStore.swift            # StoreKit 2 tip jar
│   ├── Features/
│   │   ├── Sorting/
│   │   │   ├── SortingFeature.swift      # Sorting screen
│   │   │   ├── SortingState.swift        # Sorting state
│   │   │   ├── AlbumView.swift           # Album view for adding photos to albums
│   │   │   └── Components/
│   │   │       ├── SwipeOverlay.swift
│   │   │       ├── SortingOverlays.swift
│   │   │       ├── SortingPills.swift
│   │   │       ├── LivePhotoView.swift
│   │   │       ├── VideoPlayerView.swift
│   │   │       ├── BurstSelectorView.swift
│   │   │       ├── ForcePressGesture.swift  # Force Touch for album creation
│   │   │       ├── HeartAnimation.swift
│   │   │       └── MediaBadge.swift
│   │   └── Settings/
│   │       ├── SettingsFeature.swift     # Settings screen
│   │       └── TipJarView.swift          # Tip jar for developer support
│   ├── Shared/
│   │   ├── Theme/
│   │   │   └── AppTheme.swift      # Colors, gradients, haptics
│   │   └── Extensions/
│   │       └── DateExtensions.swift
│   ├── Resources/
│   │   ├── en.lproj/
│   │   │   └── Localizable.strings # English localization
│   │   └── ja.lproj/
│   │       └── Localizable.strings # Japanese localization
│   ├── Assets.xcassets/
│   ├── Configuration.storekit      # StoreKit configuration
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
4. Use filter button to filter by photos, videos, Live Photos, etc.
5. Swipe left to add to delete queue, tap "X items delete" button to batch delete
6. Tap "Undo" button to revert the last action (can also remove from delete queue)
7. Deleted items go to iOS "Recently Deleted" (recoverable for 30 days)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

iam74k4
