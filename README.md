# art space tetra archives

## webサイトのアーカイブページ

### ビルドコマンド一覧

#### 1. ローカル開発（プレフィックスなし）
```bash
npm run serve
# または
npm run build:local
```
- `PATH_PREFIX=""` （空文字列）
- すべてのパスは `/css/`, `/upload/`, `/js/` などルートからの絶対パス
- ローカルサーバー（localhost:8080）で動作確認

#### 2. GitHub Pages サブディレクトリ配置
```bash
npm run build:ghpages
```
- `PATH_PREFIX="/info"`
- すべてのパスに `/info/` プレフィックスが追加される
- GitHub Actions で自動実行（main/develop ブランチへのpush時）
- 公開URL: https://as-tetra.github.io/info/

#### 3. カスタムドメイン（プレフィックスなし）
```bash
npm run build:custom
# または手動で
PATH_PREFIX="" npm run build
```
- カスタムドメインをGitHub Pagesに設定した場合
- プレフィックス不要なので空文字列

#### 4. その他の環境（任意のプレフィックス）
```bash
PATH_PREFIX="/myprefix" npm run build
PATH_PREFIX="/myprefix" node scripts/postbuild-add-prefix.js
```

### 仕組み

1. **ソースファイル**：すべてクリーンな状態（プレフィックスなし）で管理
   - `href="/css/tetra.css"` のまま
   - Git管理されるのはこの状態

2. **Eleventy ビルド時**：
   - `.eleventy.js` が `PATH_PREFIX` 環境変数を読み取る
   - Nunjucks テンプレートの `| url` フィルターがプレフィックスを追加
   - ショートコードも動的にプレフィックスを追加

3. **ポストビルド処理**：
   - `scripts/postbuild-add-prefix.js` が `_site/` 内の全HTMLをスキャン
   - 静的にコピーされたHTMLファイルにもプレフィックスを追加
   - CSS の `url()` にも対応

### GitHub Actions 自動デプロイ

`.github/workflows/deploy.yml` が以下を自動実行：
```yaml
- name: Build with Eleventy for GitHub Pages
  run: npm run build:ghpages
```

### 注意事項

- **ソースファイルを編集する際**：常にプレフィックスなしで記述
- **デプロイ環境が変わる場合**：適切なビルドコマンドを選択
- **ローカル確認時**：`npm run serve` を使用（自動リロード有効）
- **GitHub Pages プレビュー時**：`npm run serve:ghpages` で /info/ 付きで確認可能
