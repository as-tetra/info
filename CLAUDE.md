# CLAUDE.md - Movable Type to Eleventy Static Migration Project

## Project Overview
- 目的: 古いMovable Typeサイト（PHP動的 + 静的アーカイブ混合）を完全に静的HTML/CSS/JSのみに変換し、GitHub Pagesで公開。
- リポジトリ: https://github.com/as-tetra/info.git
- ローカルパス: /Users/unicorn195/Documents/mywork/monogswork/tetra/as-tetra.info
- 静的サイトジェネレータ: Eleventy (11ty) を使用（Node.jsベース）
- テンプレートエンジン: 優先 Nunjucks > Liquid > EJS
- 画像処理: sharp を使用（upload/ 約700MB → 最適化必須）
- 出力ディレクトリ: _site/ （GitHub Pages用）
- 公開ブランチ: main （または gh-pages）

## Tech Stack & Rules (厳守)
- Node.js LTS (v20 or v22推奨)
- 依存: @11ty/eleventy, sharp, xml2js, fs-extra, glob
- 画像最適化: 常に品質75%、最大幅1200px、withoutEnlargement: true
- PHP関連ファイル（mtview.php, image.php, php.cgiなど）は削除/無効化。リンクは静的パスに置換。
- .htaccess → GitHub Pagesでは無効 → 削除または無視
- Git LFS → 使わない（GitHub PagesでLFS非対応）
- 画像外部化推奨: Cloudflare R2 / ImgBB / AWS S3（GitHub 1GB制限回避）

## Directory Structure (重要)
- upload/          → 最適化後 optimized/ に出力
- archives/        → 年別/月別アーカイブ（既存HTML活用 or 再生成）
- 2004/～2009/     → 年別静的アーカイブ（そのままコピー可）
- css/, js/, images/ → そのまま _site/ にコピー
- data/            → MT XMLやJSONがあればここから読み込み
- _includes/       → Nunjucks partials（header.njk, footer.njk など）
- _layouts/        → ベースレイアウト（base.njk）
- _site/           → ビルド出力（gitignore推奨）

## Coding Style & Best Practices
1. 常にエラー処理を追加（try-catch, fs.existsSyncなど）
2. コードはコメント豊富に（特にsharp処理、pagination）
3. ファイル出力時は markdown コードブロックで:
4. 変更は最小限に。既存静的HTML（index.html, archives内のファイル）は可能な限り再利用。
5. ページネーション: Eleventyのpagination機能優先。手作りならコレクション + ループ。
6. localhost確認: 常に npx @11ty/eleventy --serve または npm run serve を提案。
7. サイズ対策: ビルド前に画像最適化スクリプトを走らせるよう促す。

## Workflow Preferencesまず計画（Plan）を提示 → 承認後にコード生成
- ステップバイステップで進める（例: 1. 画像最適化 → 2. Eleventy設定 → 3. データ読み込み）
- エラー時はログを分析して修正提案
- 最終確認: localhost:8080 で動作確認を促す

## NEVER DO
- PHPコードを残さない
- 動的リンク（?entry_id= など）をそのままにする
- 画像を圧縮せずにコピー
- Eleventyの設定を上書きせずに提案
- GitHub Pagesで動的機能（フォームなど）を期待させる

このプロジェクトでは上記を厳密に守ってください。質問があれば明確に確認してから進めて。
