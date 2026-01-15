# SwipeSort-iOS

![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-iOS%2018.0+-orange?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-@Observable-007AFF?style=flat-square&logo=swift&logoColor=white)

[English](./README.md) | [日本語](./README.ja.md)

直感的なスワイプ操作で写真・動画を簡単に整理できるiOSアプリ。

## 概要

SwipeSortは、直感的なスワイプ操作で写真や動画を「Keep」「削除」「お気に入り」に素早く整理できるアプリです。Swift 6とSwiftUIを採用し、モダンで美しいUIを提供します。

## 技術スタック

![iOS](https://img.shields.io/badge/iOS-18.0+-000000?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)
![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-5856D6?style=for-the-badge&logo=apple&logoColor=white)

| カテゴリ | 技術 |
|----------|------|
| 言語 | Swift 6.0 (Strict Concurrency) |
| UIフレームワーク | SwiftUI (@Observable) |
| アーキテクチャ | Feature-based |
| 写真アクセス | Photos.framework |
| データ永続化 | SwiftData |

## 機能

### 整理機能
- **右スワイプ**: Keep（残す）
- **左スワイプ**: 即削除（iOSの「最近削除した項目」に移動）
- **ダブルタップ**: お気に入り（iOSの「お気に入り」アルバムにも追加 ❤️）
- **長押し**: 動画・Live Photoの再生（押している間のみ）
- **Undo**: 直前の操作を元に戻す（削除以外）

### メディア表示
- 画像全体表示（Aspect Fit）- トリミングなし
- 写真・動画・Live Photo対応
- RAW・バースト写真対応

### その他
- 整理結果の永続化（SwiftData）
- 進捗表示（X / Y枚）
- 大量写真対応（PHCachingImageManagerによる先読みキャッシュ）
- 2タブ構成：整理 / 設定

## 要件

- iOS 18.0以上
- iPhoneのみ
- 縦向き（Portrait）のみ

## インストール

1. リポジトリをクローン

```bash
git clone https://github.com/iam74k4/SwipeSort-iOS.git
cd SwipeSort-iOS
```

2. Xcodeで `SwipeSort.xcodeproj` を開く

3. Signing & Capabilitiesで開発チームを設定

4. 実機またはシミュレーターでビルド・実行

## プロジェクト構成

```
SwipeSort-iOS/
├── SwipeSort/
│   ├── App/
│   │   ├── SwipeSortApp.swift      # アプリエントリーポイント
│   │   ├── RootView.swift          # 認証・ナビゲーション
│   │   └── AppState.swift          # グローバル状態 (@Observable)
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── SortCategory.swift  # カテゴリ enum
│   │   │   └── SortRecord.swift    # SwiftData モデル
│   │   ├── PhotoLibrary/
│   │   │   ├── PhotoAsset.swift    # アセットラッパー
│   │   │   └── PhotoLibraryClient.swift  # 写真アクセス
│   │   └── Storage/
│   │       └── SortResultStore.swift     # SwiftData ストア
│   ├── Features/
│   │   ├── Sorting/
│   │   │   ├── SortingFeature.swift      # 整理画面
│   │   │   ├── SortingState.swift        # 整理状態
│   │   │   └── Components/
│   │   │       ├── SwipeOverlay.swift
│   │   │       ├── LivePhotoView.swift
│   │   │       └── VideoPlayerView.swift
│   │   └── Settings/
│   │       └── SettingsFeature.swift     # 設定画面
│   ├── Shared/
│   │   ├── Theme/
│   │   │   └── AppTheme.swift      # カラー、グラデーション、触覚
│   │   └── Extensions/
│   │       └── DateExtensions.swift
│   ├── Assets.xcassets/
│   └── Info.plist
└── SwipeSort.xcodeproj/
```

## アーキテクチャ

- **Feature-based**: レイヤーではなく機能ごとに整理
- **@Observable**: モダンな状態管理 (iOS 17+)
- **SwiftData**: 型安全な永続化
- **Swift 6**: 厳格なコンカレンシーチェック

## 使い方

1. アプリを起動し、写真アクセスを許可
2. 表示される写真を左右にスワイプして整理、ダブルタップでお気に入り
3. 長押しで動画・Live Photoをプレビュー
4. 削除した写真はiOSの「最近削除した項目」から30日以内に復元可能

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルを参照してください。

## 作者

iam74k4
