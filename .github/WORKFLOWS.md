# GitHub Actions ワークフロー

このディレクトリには Sift iOS の CI/CD ワークフローが含まれます。

## 適切な運用（推奨フロー）

### 日々の開発

1. **develop をベースに作業する**  
   `git checkout develop && git pull`
2. **機能・修正をコミットして push**  
   `git push origin develop`
3. **CI が自動でビルド・テスト**（main / develop の push および PR で実行）
4. **main には直接コミットしない**

### リリース時（TestFlight・GitHub Release・App Store 提出）

1. **develop の内容を main にマージ**  
   `git checkout main && git pull && git merge develop --no-ff && git push origin main`
2. **main の先頭にタグを打って push**  
   `git tag v1.2.3 && git push origin v1.2.3`
3. **自動で実行されるもの**
   - **Release**: アーカイブ・GitHub Release 作成
   - **TestFlight**: アーカイブ・IPA を App Store Connect にアップロード
4. **App Store 提出**は App Store Connect から該当ビルドを選択して提出

### 手動で TestFlight だけ上げたいとき

- GitHub → Actions → **TestFlight** → Run workflow（必要なら version を入力）

---

## ワークフロー一覧

| ファイル | トリガー | 概要 |
|----------|----------|------|
| **ci.yml** | `main` / `develop` への push / PR | ビルド・テスト。DerivedData/SPM キャッシュ使用。 |
| **release.yml** | タグ `v*` の push、または手動 (workflow_dispatch) | Xcode アーカイブ作成、IPA エクスポート（development）、GitHub Release 作成。 |
| **testflight.yml** | タグ `v*`（main 上のみ）、または手動 (workflow_dispatch) | TestFlight 用アーカイブ・IPA 作成、App Store Connect へアップロード。 |

## ブランチ方針

### 現状: main + develop の2ブランチ（TestFlight 含めてこの構成で最適）

- **develop**: 開発用。日々のコミット・PR はこちらで実施。
- **main**: リリース専用。develop をマージしたうえでタグ `v*` を push すると Release / TestFlight が実行される。

TestFlight は「main にタグを打ったとき」または「手動 workflow_dispatch」でのみ動くため、**本番リリース候補と TestFlight 配布が一致**しており、2ブランチで運用しやすい構成になっています。

### main と develop だけでよいか（TestFlight を含めて）

**多くの場合で十分です。**

| 運用の形 | 向いているケース |
|----------|------------------|
| **2ブランチ（現状）** | 個人〜小規模。TestFlight は「リリース候補の確認」や「手動でときどき配布」で足りる。 |
| **2ブランチ + develop 用 TestFlight** | develop の内容を頻繁に TestFlight で配布したい（別ワークフロー追加・ビルド番号の取り方に注意）。 |
| **3ブランチ (develop → staging → main)** | 複数人で QA フェーズを分けたい。staging マージで TestFlight、本番は main のみ。 |

**推奨:** まずは **main + develop のまま**で運用し、次のような需要が出てきたら拡張を検討するとよいです。

- 「develop のマージごとに TestFlight に上げたい」→ develop 用の TestFlight ワークフローを追加（ビルド番号が App Store Connect で一意に増えるようにする必要あり）。
- 「リリース前に専用の QA ブランチでまとめてテストしたい」→ `staging`（または `release`）ブランチを挟む運用を検討。

## 共通環境変数

各ワークフローで以下を共通利用しています（必要に応じて `env` で上書き可能）。

- `SCHEME`: Sift
- `PROJECT`: Sift.xcodeproj
- `XCODE_VERSION`: 使用する Xcode バージョン（例: 26.2）

## 必要な Secrets（TestFlight / Release）

- **TestFlight**: `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`, `APPSTORE_ISSUER_ID`, `DEVELOPMENT_TEAM`
- **Release**: `GITHUB_TOKEN` は自動付与（Release 作成用）

## バージョン・ビルド番号

| ワークフロー | MARKETING_VERSION | CURRENT_PROJECT_VERSION |
|-------------|-------------------|-------------------------|
| **CI** | `scripts/version.sh` から取得 | `scripts/version.sh` から取得 |
| **TestFlight** | タグ名 or 手動入力 | `github.run_number`（自動インクリメント） |
| **Release** | タグ名 | コミット数 |

TestFlight のビルド番号は `github.run_number` を使用するため、自動で増加し重複エラーが発生しません。
