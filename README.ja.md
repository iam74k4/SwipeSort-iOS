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
- **左スワイプ**: 削除キューに追加（「X件削除」ボタンでまとめて削除）
- **ダブルタップ**: お気に入り（iOSの「お気に入り」アルバムにも追加 ❤️）
- **長押し**: 動画・Live Photoの再生（押している間のみ）
- **Undo**: 直前の操作を元に戻す（削除キューからも取り消し可能）
- **フィルター**: 写真・動画・Live Photo・スクショで絞り込み
- **カテゴリフィルター**: トップバーの統計ピル（Keep/削除/お気に入り）をタップして、そのカテゴリのみを表示
- **アルバム作成**: Keep またはお気に入りの統計ピルを Force Touch で押してアルバムに写真を追加

### メディア表示
- 画像全体表示（Aspect Fit）- トリミングなし
- 写真・動画・Live Photo対応
- RAW・バースト写真対応
- 撮影日時の表示（相対時間表示）

### その他
- 整理結果の永続化（SwiftData）
- 進捗表示（X / Y枚）
- 統計表示（Keep/削除/お気に入りの件数をリアルタイム表示）
- 大量写真対応（PHCachingImageManagerによる先読みキャッシュ）
- 2タブ構成：整理 / 設定
- Tip Jar: オプションのアプリ内課金で開発者を支援（StoreKit 2）
- 設定画面：統計、操作ガイド、触覚フィードバックの切り替え、サポートリンク
- アルバム作成：ドラッグ＆ドロップで整理した写真を iOS アルバムに追加

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

## ブランチ方針・運用

- **develop**: 開発用のデフォルトブランチ。日々のコミット・PR はこちらで行います。
- **main**: リリース専用。リリース時のみ更新（develop をマージしたうえでバージョンタグを push）。機能開発の直接 push は行いません。

**推奨運用:** 普段は `develop` で開発 → リリース時は `develop` を `main` にマージし、`main` から `v*` タグを push → Release / TestFlight が自動実行。手順の詳細は [.github/README.md](.github/README.md) を参照。

## バージョン管理

このプロジェクトでは Git タグに基づいた**自動バージョン管理**を採用しています。ビルド時に自動でバージョンが設定されるため、手動でバージョン番号を更新する必要はありません。

### 仕組み

- **main ブランチ**: 最新の Git タグからバージョンを取得（例: `v1.0.0` → `1.0.0`）
- **develop ブランチ**: 次のパッチバージョンを使用（例: `v1.0.0` → `1.0.1`）
- **ビルド番号**: 最新タグからのコミット数から自動計算

### バージョンタグの作成

新しいバージョンタグを作成するには：

```bash
git tag v1.0.0
git push origin v1.0.0
```

タグ形式はセマンティックバージョニングに従ってください: `vX.Y.Z`（例: `v1.0.0`, `v1.1.0`, `v2.0.0`）

### 自動バージョン設定

- **ローカルビルド**: バージョンスクリプトがビルド時に `project.pbxproj` を自動更新（変更は Git にコミットされません）
- **CI/CD**: GitHub Actions ワークフローでバージョンスクリプトが自動使用されます
- **手動操作不要**: プロジェクトをビルドするだけで、バージョンが自動設定されます

### トラブルシューティング

- **タグが見つからない場合**: スクリプトはデフォルト値を使用します（main: `0.0.1`、develop: `0.0.2`）
- **Git リポジトリでない場合**: スクリプトはデフォルト値を使用してビルドを続行します
- **ビルド番号の増加**: コミットごとにビルド番号が自動的に増加します

### 注意

ビルド後に `project.pbxproj` ファイルが変更済みと表示される場合がありますが、**これらの変更をコミットする必要はありません**。バージョンはビルド時にのみ更新されます。

## 設定

サポート用のメール・外部リンクは `SwipeSort/Info.plist` から読みます。ビルドに合わせて次のキーを編集してください。

- **SwipeSortSupportEmail**: フィードバック用メールアドレス（mailto:）。未設定または空の場合、設定画面で「お問い合わせ用メールアドレスが未設定です。」と表示されます。
- **SwipeSortDiscordURL**: Discord 招待URL。
- **SwipeSortAppStoreID**: App Store ID（レビューリンク用）。
- **SwipeSortPrivacyPolicyURL**: プライバシーポリシーURL。

リポジトリにはプレースホルダのままにし、実値はビルド時に注入（xcconfig や CI など）することもできます。

## プロジェクト構成

```
SwipeSort-iOS/
├── .github/
│   ├── README.md                   # ワークフロードキュメント
│   └── workflows/
│       ├── ci.yml                  # ビルド・テスト
│       ├── release.yml             # GitHub Release
│       └── testflight.yml          # TestFlight アップロード
├── scripts/
│   └── version.sh                  # 自動バージョン管理
├── LICENSE                         # MIT ライセンス
├── README.md
├── README.ja.md
├── SwipeSort/
│   ├── App/
│   │   ├── SwipeSortApp.swift      # アプリエントリーポイント
│   │   ├── RootView.swift          # 認証状態に応じた表示とタブナビゲーション
│   │   └── AppState.swift          # グローバル状態 (@Observable)
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── SortCategory.swift  # カテゴリ enum
│   │   │   └── SortRecord.swift    # SwiftData モデル
│   │   ├── PhotoLibrary/
│   │   │   ├── PhotoAsset.swift    # アセットラッパー
│   │   │   └── PhotoLibraryClient.swift  # 写真アクセス
│   │   ├── Storage/
│   │   │   └── SortResultStore.swift     # SwiftData ストア
│   │   └── Store/
│   │       └── TipStore.swift            # StoreKit 2 Tip Jar
│   ├── Features/
│   │   ├── Sorting/
│   │   │   ├── SortingFeature.swift      # 整理画面
│   │   │   ├── SortingState.swift        # 整理状態
│   │   │   ├── AlbumView.swift           # アルバムに写真を追加する画面
│   │   │   └── Components/
│   │   │       ├── SwipeOverlay.swift
│   │   │       ├── SortingOverlays.swift
│   │   │       ├── SortingPills.swift
│   │   │       ├── LivePhotoView.swift
│   │   │       ├── VideoPlayerView.swift
│   │   │       ├── BurstSelectorView.swift
│   │   │       ├── ForcePressGesture.swift  # アルバム作成用 Force Touch
│   │   │       ├── HeartAnimation.swift
│   │   │       └── MediaBadge.swift
│   │   └── Settings/
│   │       ├── SettingsFeature.swift     # 設定画面
│   │       └── TipJarView.swift          # 開発者支援のTip Jar
│   ├── Shared/
│   │   ├── Theme/
│   │   │   └── AppTheme.swift      # カラー、グラデーション、触覚
│   │   └── Extensions/
│   │       └── DateExtensions.swift
│   ├── Resources/
│   │   ├── en.lproj/
│   │   │   └── Localizable.strings # 英語ローカライズ
│   │   └── ja.lproj/
│   │       └── Localizable.strings # 日本語ローカライズ
│   ├── Assets.xcassets/
│   ├── Configuration.storekit      # StoreKit 設定
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
4. フィルターボタンで写真・動画・Live Photoなどで絞り込み
5. 左スワイプで削除キューに追加し、「X件削除」ボタンでまとめて削除
6. 「戻す」ボタンで直前の操作を取り消し（削除キューからも取り消し可能）
7. 削除した写真はiOSの「最近削除した項目」から30日以内に復元可能

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルを参照してください。

## 作者

iam74k4
