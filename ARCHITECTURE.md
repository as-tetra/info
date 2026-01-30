# art space tetra - アーキテクチャドキュメント

**Movable Type → Eleventy 静的サイト移行プロジェクト**

最終更新: 2026-01-30

---

## 📋 目次

1. [プロジェクト概要](#プロジェクト概要)
2. [アーキテクチャ設計](#アーキテクチャ設計)
3. [ディレクトリ構造](#ディレクトリ構造)
4. [ビルドシステム](#ビルドシステム)
5. [テンプレートシステム](#テンプレートシステム)
6. [データフロー](#データフロー)
7. [コンポーネント設計](#コンポーネント設計)
8. [ページネーションシステム](#ページネーションシステム)
9. [パフォーマンス最適化](#パフォーマンス最適化)
10. [デプロイメント](#デプロイメント)
11. [開発ワークフロー](#開発ワークフロー)
12. [トラブルシューティング](#トラブルシューティング)

---

## 🎯 プロジェクト概要

### 目的

2004年から運営されてきたMovable Type（MT）ベースの動的サイトを、完全静的HTMLサイトに移行し、GitHub Pagesで公開可能にする。

### 背景

- **元のシステム**: Movable Type 3.x-6.x + PHP動的ページ + 静的アーカイブの混合
- **問題点**:
  - PHPサーバー必須（GitHub Pagesで不可）
  - 画像容量 700MB超（最適化なし）
  - メンテナンス困難（MTの更新停止）
  - セキュリティリスク（古いPHPコード）

### 技術スタック

| カテゴリ | 技術 | バージョン |
|---------|------|-----------|
| SSG | Eleventy | 3.1.2 |
| テンプレート | Nunjucks | - |
| ランタイム | Node.js | ≥20.0.0 |
| 画像処理 | Sharp | 0.33.x |
| HTML解析 | Cheerio | 1.0.x |
| ファイル操作 | fs-extra | 11.x |
| パターンマッチ | glob | 10.x |
| ホスティング | GitHub Pages | - |

### パフォーマンス指標

| 指標 | 移行前 | 移行後 | 削減率 |
|-----|--------|--------|--------|
| サイト合計 | ~1GB | 323MB | 67.7% |
| 画像容量 | 218MB | 150MB | 31.2% |
| _site/ ビルド | - | 203MB | - |
| コード重複 | 380行 | 107行 | 71.8% |
| ページ生成 | 手動 | 自動 | - |
| ビルド時間 | - | 3.33秒 | - |

---

## 🏗️ アーキテクチャ設計

### システムアーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                        ソースファイル                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  テンプレート           データ              静的アセット          │
│  *.njk               _data/             upload/            │
│  *-paginated/        *.js, *.json      css/, js/           │
│  _includes/          entries, pages    images/             │
│                                                             │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │   Eleventy Engine    │
    │  (Node.js runtime)   │
    └──────────┬───────────┘
               │
               ├─── Nunjucks テンプレート処理
               ├─── データ読み込み (_data/)
               ├─── ページネーション生成
               ├─── PassthroughCopy (静的ファイル)
               └─── フィルター・ショートコード適用
               │
               ▼
    ┌──────────────────────┐
    │   _site/ (出力)       │
    │   2,295 HTMLファイル  │
    │   203MB               │
    └──────────┬───────────┘
               │
               ▼ (ポストビルド)
    ┌──────────────────────┐
    │ postbuild-add-prefix │
    │ PATH_PREFIX 適用      │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────┐
    │   GitHub Pages       │
    │   https://...        │
    └──────────────────────┘
```

### 設計原則

1. **データとプレゼンテーションの分離**
   - データ: `_data/` (JSON, JS)
   - テンプレート: `_includes/`, `*-paginated/`
   - 静的アセット: `upload/`, `css/`, `js/`

2. **コンポーネント駆動開発**
   - 再利用可能なコンポーネント (`_includes/components/`)
   - DRY原則（Don't Repeat Yourself）
   - 単一責任の原則

3. **パフォーマンスファースト**
   - 画像最適化（Sharp）
   - 遅延読み込み（lazy loading）
   - 最小限のJavaScript

4. **環境適応性**
   - PATH_PREFIX による柔軟なデプロイ
   - ローカル開発とプロダクションの環境分離

---

## 📁 ディレクトリ構造

### プロジェクトルート

```
as-tetra.info/
├── _data/                    # データファイル（Eleventy自動読み込み）
│   ├── archiveEntries.json   # アーカイブエントリー（全年）
│   ├── archivePages.js       # 年別ページネーションデータ生成
│   ├── categoriesData.js     # カテゴリーメタデータ
│   ├── categoryPages.js      # カテゴリーページネーション
│   ├── entries.json          # 全エントリー
│   ├── genreEntries.json     # ジャンル別エントリー
│   ├── genrePages.js         # ジャンルページネーション
│   ├── site.json             # サイト全体設定
│   └── tetraPages.js         # tetraプロジェクトページネーション
│
├── _includes/                # テンプレートパーツ
│   ├── layouts/
│   │   └── base.njk          # ベースレイアウト
│   └── components/           # 再利用コンポーネント
│       ├── entry-card-simple.njk          # シンプルエントリーカード
│       ├── entry-card-bilingual.njk       # バイリンガルカード
│       ├── entry-card-bilingual-full.njk  # フルカード
│       ├── footer.njk                     # フッター
│       ├── header.njk                     # ヘッダー
│       ├── main-navigation.njk            # メインナビゲーション
│       ├── nav-sns.njk                    # SNSナビゲーション
│       └── pagination.njk                 # ページネーション
│
├── archives-paginated/       # 全エントリーアーカイブページネーション
│   └── index.njk
├── category-paginated/       # カテゴリーページネーション
│   └── index.njk
├── genre-paginated/          # ジャンルページネーション
│   └── index.njk
├── tetra-paginated/          # tetraプロジェクトページネーション
│   └── index.njk
├── year-archives/            # 年別アーカイブページネーション
│   └── index.njk
│
├── scripts/                  # ビルド・メンテナンススクリプト
│   ├── extract-*.js          # データ抽出スクリプト
│   ├── optimize-*.js         # 画像最適化
│   ├── fix-*.js              # リンク修正
│   └── postbuild-add-prefix.js # PATH_PREFIX適用
│
├── upload/                   # 画像アセット（218MB → 150MB）
├── css/                      # スタイルシート
├── js/                       # JavaScript
├── images/                   # サイトアイコン・ロゴ
├── archives/                 # 既存アーカイブ（MTが生成、コピー）
├── 2004/ ~ 2009/             # 年別静的アーカイブ（コピー）
│
├── .eleventy.js              # Eleventy設定ファイル
├── .eleventyignore           # ビルド除外設定
├── package.json              # プロジェクト設定
├── CLAUDE.md                 # プロジェクト指示書
└── ARCHITECTURE.md           # 本ドキュメント
```

### _site/ 出力構造

```
_site/
├── index.html                          # トップページ
├── genre/                              # ジャンル別アーカイブ（生成）
│   ├── music_event/
│   │   ├── index.html                 # 1ページ目
│   │   └── page/
│   │       ├── 2/index.html
│   │       └── ...
│   ├── exhibition/
│   └── ...
├── archives/                           # 年別アーカイブ
│   ├── 2026/
│   │   ├── index.html                 # 年別一覧（生成）
│   │   ├── page/
│   │   │   └── 2/index.html
│   │   └── 260106200000.html          # 個別エントリー（コピー）
│   └── ...
├── tetra/                              # tetraプロジェクト
│   ├── index.html
│   └── page/
│       ├── 2/index.html
│       └── ...
├── upload/                             # 画像（PassthroughCopy）
├── css/, js/, images/                  # アセット（PassthroughCopy）
└── .nojekyll                           # GitHub Pages設定
```

---

## ⚙️ ビルドシステム

### ビルドフロー

```
┌─────────────┐
│ npm run ... │
└──────┬──────┘
       │
       ├─ clean ──────────► rm -rf _site/
       │
       ├─ prebuild ───────► clean
       │
       ├─ build ──────────► Eleventy処理
       │                    ├─ テンプレート解析
       │                    ├─ データ読み込み
       │                    ├─ ページネーション生成
       │                    └─ 静的ファイルコピー
       │
       └─ postbuild ──────► PATH_PREFIX適用
                            └─ _site/ 内HTMLを書き換え
```

### ビルドコマンド

| コマンド | 用途 | PATH_PREFIX | 出力先 |
|---------|------|-------------|--------|
| `npm run serve` | ローカル開発 | `""` | localhost:8080 |
| `npm run build:local` | ローカルビルド | `""` | _site/ |
| `npm run build:ghpages` | GitHub Pages | `/info` | _site/ |
| `npm run build:custom` | カスタムドメイン | `""` | _site/ |

### PATH_PREFIX の仕組み

#### 1. ビルド時（.eleventy.js）

```javascript
const pathPrefix = process.env.PATH_PREFIX || '';

return {
  ...(pathPrefix && { pathPrefix }),
  // ...
};
```

#### 2. テンプレート内（Nunjucks）

```nunjucks
<a href="{{ '/' | url }}">Home</a>
<!-- PATH_PREFIX="" → / -->
<!-- PATH_PREFIX="/info" → /info/ -->

<img src="{{ '/upload/2025/image.jpg' | url }}">
<!-- PATH_PREFIX="" → /upload/2025/image.jpg -->
<!-- PATH_PREFIX="/info" → /info/upload/2025/image.jpg -->
```

#### 3. ポストビルド（scripts/postbuild-add-prefix.js）

```javascript
// 静的にコピーされたHTMLにもPATH_PREFIXを適用
content = content.replace(
  /href="\/([^"]*)"/g,
  `href="${pathPrefix}/$1"`
);
```

### Eleventy設定（.eleventy.js）

#### PassthroughCopy

静的ファイルを`_site/`にそのままコピー:

```javascript
// 画像・アセット
eleventyConfig.addPassthroughCopy('upload');
eleventyConfig.addPassthroughCopy('css');
eleventyConfig.addPassthroughCopy('js');
eleventyConfig.addPassthroughCopy('images');

// 年別アーカイブ
eleventyConfig.addPassthroughCopy('2004');
// ... 2009まで

// 既存アーカイブ（個別エントリーのみ）
eleventyConfig.addPassthroughCopy('archives/**/*.html');
eleventyConfig.ignores.add('archives/**/index.html');
```

#### フィルター

```javascript
// 日付フォーマット
eleventyConfig.addFilter('dateFormat', (date) => { /* ... */ });

// 配列操作
eleventyConfig.addFilter('max', (arr) => Math.max(...arr));
eleventyConfig.addFilter('min', (arr) => Math.min(...arr));
eleventyConfig.addFilter('length', (arr) => arr.length);

// 年でフィルタリング
eleventyConfig.addFilter('filterByYear', (entries, year) => { /* ... */ });
```

#### ショートコード

```javascript
// 最適化画像（PATH_PREFIX対応）
eleventyConfig.addShortcode('image', (src, alt, className) => {
  const optimizedSrc = pathPrefix ? `${pathPrefix}${src}` : src;
  return `<img src="${optimizedSrc}" alt="${alt}" loading="lazy">`;
});
```

---

## 🎨 テンプレートシステム

### レイアウト階層

```
base.njk (ベースレイアウト)
├── header.njk
├── nav-sns.njk
└── footer.njk
    │
    ├─ genre-paginated/index.njk
    ├─ tetra-paginated/index.njk
    ├─ year-archives/index.njk
    ├─ archives-paginated/index.njk
    └─ category-paginated/index.njk
```

### base.njk（ベースレイアウト）

```nunjucks
<!DOCTYPE html>
<html lang="{{ lang | default('ja') }}">
<head>
  <meta charset="utf-8">
  <title>{% if title %}{{ title }} | {% endif %}art space tetra</title>
  <link rel="stylesheet" href="{{ '/css/tetra_base.css' | url }}">
  <!-- ... -->
</head>
<body class="responsive">

{# Header #}
{% include "components/header.njk" %}
{% include "components/nav-sns.njk" %}
</div>

{# Container #}
<div id="container">
  {% block content %}
    {{ content | safe }}
  {% endblock %}
</div>

{# Footer #}
{% include "components/footer.njk" %}

</body>
</html>
```

### ページネーションテンプレート構造

全てのページネーションテンプレートは統一された構造:

```nunjucks
---
pagination:
  data: <データソース>
  size: 1
  alias: page
permalink: "{{ page.permalink }}"
layout: base.njk
eleventyComputed:
  title: "{{ page.title }}"
---

<div class="main">
  {# タイトル #}
  <div class="block_box">
    <h1 class="menu_title">{{ page.title }}</h1>
  </div>

  {# エントリーリスト #}
  {% for entry in page.entries %}
  {% include "components/entry-card-*.njk" %}
  {% endfor %}

  {# ページネーション #}
  {% set customPagination = page %}
  {% set baseUrl = '/path' %}
  {% include "components/pagination.njk" %}

  {# メインナビゲーション #}
  {% include "components/main-navigation.njk" %}
</div>
```

---

## 📊 データフロー

### データ生成フロー

```
┌────────────────────────────────────┐
│ 既存HTMLファイル（MTが生成）          │
│ archives/YYYY/*.html               │
│ genre/**/*.html                    │
│ tetra/index.html                   │
└───────────┬────────────────────────┘
            │
            ▼ (Cheerio で解析)
┌────────────────────────────────────┐
│ 抽出スクリプト                       │
│ scripts/extract-*.js               │
│ - extract-archive-entries.js       │
│ - extract-genre-entries.js         │
│ - extract-tetra-entries.js         │
└───────────┬────────────────────────┘
            │
            ▼ (JSON出力)
┌────────────────────────────────────┐
│ データファイル                       │
│ _data/                             │
│ - archiveEntries.json              │
│ - genreEntries.json                │
│ - entries.json                     │
└───────────┬────────────────────────┘
            │
            ▼ (Eleventy読み込み)
┌────────────────────────────────────┐
│ ページネーションデータ生成            │
│ _data/*Pages.js                    │
│ - archivePages.js                  │
│ - genrePages.js                    │
│ - tetraPages.js                    │
└───────────┬────────────────────────┘
            │
            ▼ (テンプレート適用)
┌────────────────────────────────────┐
│ HTMLページ生成                      │
│ _site/genre/music_event/index.html │
│ _site/archives/2025/index.html     │
│ _site/tetra/page/2/index.html      │
└────────────────────────────────────┘
```

### データファイル詳細

#### archiveEntries.json

全年の全エントリーを格納:

```json
[
  {
    "date": "2026.01.14",
    "isPast": false,
    "titleJp": "《Cursed Cards 素敵な呪い》",
    "titleEn": "",
    "url": "/archives/2026/260114000000.html",
    "imgSrc": "/upload/2026/image.jpeg",
    "imgAlt": "...",
    "imgWidth": "168",
    "bodyJp": "<p>...</p>",
    "bodyEn": "<p>...</p>",
    "year": "2026"
  }
  // ... 800+ entries
]
```

#### archivePages.js

年別ページネーションデータを動的生成:

```javascript
module.exports = function() {
  const entries = require('./archiveEntries.json');
  const years = [...new Set(entries.map(e => e.year))].sort().reverse();

  const pages = [];

  years.forEach(year => {
    const yearEntries = entries.filter(e => e.year === year);
    const pageSize = 30;

    for (let i = 0; i < yearEntries.length; i += pageSize) {
      const pageEntries = yearEntries.slice(i, i + pageSize);
      const pageNumber = Math.floor(i / pageSize);
      const totalPages = Math.ceil(yearEntries.length / pageSize);

      pages.push({
        year,
        pageNumber,
        totalPages,
        entryCount: yearEntries.length,
        entries: pageEntries,
        permalink: pageNumber === 0
          ? `archives/${year}/index.html`
          : `archives/${year}/page/${pageNumber + 1}/index.html`,
        isFirstPage: pageNumber === 0,
        isLastPage: pageNumber === totalPages - 1
      });
    }
  });

  return pages;
};
```

#### genrePages.js

ジャンル別ページネーション:

```javascript
module.exports = function() {
  const genreEntries = require('./genreEntries.json');
  const pages = [];

  Object.keys(genreEntries).forEach(genreSlug => {
    const entries = genreEntries[genreSlug].entries;
    const pageSize = 30;

    // ページネーション生成ロジック
    // ... (archivePagesと同様)
  });

  return pages;
};
```

---

## 🧩 コンポーネント設計

### コンポーネント一覧

| コンポーネント | 用途 | 使用箇所 |
|--------------|------|---------|
| `header.njk` | サイトヘッダー | base.njk |
| `nav-sns.njk` | SNSナビゲーション | base.njk |
| `footer.njk` | サイトフッター | base.njk |
| `main-navigation.njk` | メインナビゲーション | 全ページネーション |
| `pagination.njk` | ページネーション | 全ページネーション |
| `entry-card-simple.njk` | シンプルカード | category-paginated |
| `entry-card-bilingual.njk` | バイリンガルカード | genre-paginated |
| `entry-card-bilingual-full.njk` | フルカード | year-archives, tetra |

### コンポーネント設計原則

1. **単一責任**: 1コンポーネント = 1機能
2. **パラメーター化**: `entry` オブジェクトで統一
3. **再利用性**: 最大限の再利用を前提
4. **一貫性**: 統一されたHTML構造

### main-navigation.njk（詳細）

全ページに共通のナビゲーションメニュー:

```nunjucks
<!-- sub menu -->
<div class="block_box">
  <h1 class="menu_title"><a href="{{ '/' | url }}">»&nbsp;HOME</a></h1>
</div>
<div class="block_box">
  <h1 class="menu_title">ABOUT</h1>
  <div class="dots_line"></div>
  <ul>
    <li><a href="{{ '/tetra/' | url }}">own project</a></li>
    <li><a href="{{ '/archives/2004/040101100000.html' | url }}">outline</a></li>
    <li><a href="{{ '/archives/2013/130608114205.html' | url }}">free paper</a></li>
    <li><a href="{{ '/archives/2004/040101050000.html' | url }}">access map</a></li>
    <!-- ... -->
  </ul>
</div>
<div class="block_box">
  <h1 class="menu_title">SPECIAL</h1>
  <!-- ... -->
</div>
<div class="block_box">
  <h1 class="menu_title">CATEGORY</h1>
  <ul>
    <li><a href="{{ '/genre/exhibition/' | url }}">exhibition</a></li>
    <li><a href="{{ '/genre/music_event/' | url }}">music event</a></li>
    <!-- ... -->
  </ul>
</div>
<div class="block_box">
  <h1 class="menu_title">ARCHIVES</h1>
  <ul class="year">
    <li><a href="{{ '/archives/2026/' | url }}">2026</a></li>
    <!-- ... 2004まで -->
  </ul>
</div>
<!-- end of sub menu -->
```

### pagination.njk（統一ページネーション）

カスタムページネーションとEleventyページネーションの両方に対応:

```nunjucks
{% if customPagination %}
  {# カスタムページネーション（archivePages, genrePagesなど） #}
  {% set currentPage = customPagination.pageNumber %}
  {% set totalPages = customPagination.totalPages %}

  {% if totalPages > 1 %}
  <div class="pagination">
    {% if currentPage > 0 %}
    <a href="{{ baseUrl }}/{% if currentPage > 1 %}page/{{ currentPage }}/{% endif %}index.html">« Prev</a>
    {% endif %}

    {% for i in range(0, totalPages) %}
      {% if i === currentPage %}
      <span class="current">{{ i + 1 }}</span>
      {% else %}
      <a href="{{ baseUrl }}/{% if i > 0 %}page/{{ i + 1 }}/{% endif %}index.html">{{ i + 1 }}</a>
      {% endif %}
    {% endfor %}

    {% if currentPage < totalPages - 1 %}
    <a href="{{ baseUrl }}/page/{{ currentPage + 2 }}/index.html">Next »</a>
    {% endif %}
  </div>
  {% endif %}
{% endif %}

{% if eleventyPagination %}
  {# Eleventyネイティブページネーション #}
  {# ... #}
{% endif %}
```

### entry-card-bilingual-full.njk（詳細）

最も詳細なエントリーカード（year-archives, tetra用）:

```nunjucks
<div class="{% if entry.isPast %}block_box2{% else %}block_box{% endif %}" ontouchstart="">
  <div class="{% if entry.isPast %}date_past{% else %}date{% endif %}">{{ entry.date }}</div>

  <h1>
    <a href="{{ entry.url | url }}">
      <span class="en">{{ entry.titleEn }}</span>
      <span class="jp">{{ entry.titleJp }}</span>
    </a>
  </h1>

  {% if entry.imgSrc %}
  <a href="{{ entry.url | url }}">
    <img src="{{ entry.imgSrc | url }}"
         alt="{{ entry.imgAlt }}"
         {% if entry.imgWidth %}width="{{ entry.imgWidth }}"{% endif %}>
  </a>
  {% endif %}

  <span class="jp">{{ entry.bodyJp | safe }}</span>
  <span class="en">{{ entry.bodyEn | safe }}</span>
</div>
```

---

## 📄 ページネーションシステム

### ページネーション種別

| 種別 | テンプレート | データソース | ページサイズ |
|-----|------------|------------|------------|
| ジャンル別 | genre-paginated | genrePages.js | 30 |
| 年別 | year-archives | archivePages.js | 30 |
| tetraプロジェクト | tetra-paginated | tetraPages.js | 30 |
| カテゴリー | category-paginated | categoryPages.js | 15 |
| 全エントリー | archives-paginated | entries.json | 15 |

### ページネーション実装パターン

#### パターン1: カスタムデータ駆動（推奨）

**利点**: 完全制御、柔軟性、複雑なロジック可能

```nunjucks
---
pagination:
  data: genrePages        # _data/genrePages.js
  size: 1                 # 1つのページデータ = 1ページ
  alias: page
permalink: "{{ page.permalink }}"
---

{% for entry in page.entries %}
  {% include "components/entry-card-bilingual.njk" %}
{% endfor %}

{% set customPagination = page %}
{% set baseUrl = '/genre/' + page.categorySlug %}
{% include "components/pagination.njk" %}
```

#### パターン2: Eleventyネイティブ

**利点**: シンプル、標準機能

```nunjucks
---
pagination:
  data: entries           # _data/entries.json
  size: 15                # 15エントリー = 1ページ
  alias: items
  reverse: false
permalink: "archives/page-{{ pagination.pageNumber + 1 }}/index.html"
---

{% for entry in items %}
  {% include "components/entry-card-simple.njk" %}
{% endfor %}

{% set eleventyPagination = pagination %}
{% include "components/pagination.njk" %}
```

### ページネーション生成例

#### 入力（genreEntries.json）

```json
{
  "music_event": {
    "name": "music event",
    "entries": [
      { "date": "2026.01.15", "titleJp": "...", /* ... */ },
      // ... 337 entries
    ]
  }
}
```

#### 処理（genrePages.js）

```javascript
const genreEntries = require('./genreEntries.json');
const pages = [];

Object.keys(genreEntries).forEach(genreSlug => {
  const { name, entries } = genreEntries[genreSlug];
  const pageSize = 30;
  const totalPages = Math.ceil(entries.length / pageSize);

  for (let i = 0; i < entries.length; i += pageSize) {
    pages.push({
      categorySlug: genreSlug,
      categoryName: name,
      categoryCount: entries.length,
      pageNumber: Math.floor(i / pageSize),
      totalPages,
      entries: entries.slice(i, i + pageSize),
      permalink: i === 0
        ? `genre/${genreSlug}/index.html`
        : `genre/${genreSlug}/page/${Math.floor(i / pageSize) + 1}/index.html`
    });
  }
});

module.exports = pages;
```

#### 出力（_site/）

```
_site/genre/music_event/
├── index.html              # 1-30件
└── page/
    ├── 2/index.html        # 31-60件
    ├── 3/index.html        # 61-90件
    └── ...
    └── 12/index.html       # 331-337件
```

---

## 🚀 パフォーマンス最適化

### Phase 1-2: 実施済み最適化（2026-01-30）

#### 1. 不要ファイル削除（48MB削減）

```bash
# 削除対象
rm -rf cgi-bin/acmailer3/      # 3.1 MB
rm -rf cgi-bin/mailform/       # 12 MB
rm -rf cgi-bin/tetra_mt/       # 12 MB
rm -rf imagecache/             # 21 MB
```

#### 2. サムネイル重複削除（67MB削減）

```bash
# scripts/delete-thumbnails.js
# 638個の -thumb.* ファイルを削除
# 実ファイルと同サイズの無駄なサムネイル
```

#### 3. コンポーネント化（380行 → 107行）

- ページネーション統合: 4テンプレート → 1コンポーネント
- エントリーカード: 3種類のコンポーネント作成
- ヘッダー・フッター: コンポーネント抽出
- ナビゲーション: main-navigation.njk 作成

#### 4. GIF→WebP変換（12MB削減）

```javascript
// scripts/optimize-large-images.js
const sharp = require('sharp');

await sharp(inputPath, { animated: true })
  .webp({ quality: 80, effort: 6 })
  .toFile(outputPath);

// 例: Untitled24.gif (6.8MB) → Untitled24.webp (0.27MB) = 95.4%削減
```

#### 5. PNG再圧縮（32ファイル、平均75%削減）

```javascript
await sharp(inputPath)
  .png({ quality: 85, compressionLevel: 9 })
  .resize({ width: 1200, withoutEnlargement: true })
  .toFile(outputPath);
```

#### 6. 画像リンク修正（3,906 → 257破損リンク、93.4%修正）

```javascript
// scripts/comprehensive-image-fix.js
// - 実ファイルスキャン（1,562ファイル）
// - インテリジェントマッピング（同年フォルダ優先）
// - -thumb削除、拡張子変換
```

### パフォーマンス指標（2026-01-30時点）

| 指標 | 値 |
|-----|---|
| 総HTMLファイル | 2,295ファイル |
| ナビゲーション含むページ | 1,288ファイル（56%） |
| _site/サイズ | 203MB |
| ビルド時間 | 3.33秒 |
| ファイルあたりビルド時間 | 4.1ms |
| PassthroughCopy | 3,802ファイル |
| 生成ファイル | 809ファイル |

### 最適化ベストプラクティス

1. **画像最適化**
   - 品質: 75-85%
   - 最大幅: 1200px
   - withoutEnlargement: true（拡大しない）
   - GIF → WebP（アニメーション対応）

2. **遅延読み込み**
   ```html
   <img src="..." loading="lazy">
   ```

3. **リンク整合性**
   - 実ファイルとリンクの自動照合
   - ビルド時検証

---

## 🌐 デプロイメント

### GitHub Pages設定

#### リポジトリ構造

```
https://github.com/as-tetra/info
├── main branch
│   ├── .github/workflows/deploy.yml
│   ├── _site/ (gitignore)
│   └── ... (ソースファイル)
└── gh-pages branch (自動デプロイ)
    └── _site/ の内容
```

#### GitHub Actions（.github/workflows/deploy.yml）

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main, develop]
  workflow_dispatch:

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Build with Eleventy for GitHub Pages
        run: npm run build:ghpages

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./_site
          publish_branch: gh-pages
```

#### デプロイフロー

```
┌──────────────┐
│ git push main│
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ GitHub Actions起動   │
│ - checkout           │
│ - npm ci             │
│ - npm run build:ghpages
│   └─ PATH_PREFIX=/info
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ _site/ ビルド完了    │
│ 全パスに /info/ 付与 │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ gh-pages ブランチ更新│
│ _site/ を push       │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ GitHub Pages公開     │
│ https://as-tetra.github.io/info/
└──────────────────────┘
```

### 環境別デプロイ

#### ローカル開発

```bash
npm run serve
# → http://localhost:8080
# PATH_PREFIX=""
```

#### GitHub Pages（サブディレクトリ）

```bash
npm run build:ghpages
# → https://as-tetra.github.io/info/
# PATH_PREFIX="/info"
```

#### カスタムドメイン

```bash
npm run build:custom
# → https://as-tetra.info/
# PATH_PREFIX=""
```

---

## 🛠️ 開発ワークフロー

### 開発環境セットアップ

```bash
# 1. リポジトリクローン
git clone https://github.com/as-tetra/info.git
cd info

# 2. 依存関係インストール
npm install

# 3. ローカルサーバー起動
npm run serve
# → http://localhost:8080

# 4. ビルド確認
npm run build:local
```

### 一般的な作業フロー

#### 1. 新しいエントリー追加

```bash
# 1. 既存HTMLから抽出
npm run extract-archive-entries   # archives/ から
npm run extract-genre-entries     # genre/ から
npm run extract-tetra-entries     # tetra/ から

# 2. ビルド
npm run build:local

# 3. 確認
npm run serve
# → http://localhost:8080/archives/2026/
```

#### 2. 画像最適化

```bash
# 全画像最適化
npm run optimize-images

# WebP変換のみ
npm run optimize-images:webp

# 大容量ファイルのみ
node scripts/optimize-large-images.js
```

#### 3. リンク修正

```bash
# 破損リンクチェック
node scripts/check-broken-images.js

# 包括的修正
node scripts/comprehensive-image-fix.js

# サムネイルリンク修正
node scripts/fix-all-thumbs-comprehensive.js
```

#### 4. コンポーネント追加・修正

```bash
# 1. コンポーネント作成
touch _includes/components/new-component.njk

# 2. テンプレートで使用
{% include "components/new-component.njk" %}

# 3. ホットリロードで確認
# npm run serve が自動検知して再ビルド
```

### Git ワークフロー

```bash
# 1. ブランチ作成
git checkout -b feature/new-feature

# 2. 変更をコミット
git add .
git commit -m "Add new feature"

# 3. プッシュ
git push origin feature/new-feature

# 4. Pull Request作成
# GitHub UI で main へマージ

# 5. GitHub Actions が自動デプロイ
```

---

## 🐛 トラブルシューティング

### よくある問題と解決策

#### 1. ビルドエラー: "Cannot find module '_data/...'"

**原因**: データファイルが生成されていない

**解決策**:
```bash
# データ抽出スクリプトを実行
npm run extract-archive-entries
npm run extract-genre-entries
npm run extract-tetra-entries

# 再ビルド
npm run build:local
```

#### 2. 画像が表示されない（404）

**原因A**: PATH_PREFIX不一致

**解決策**:
```bash
# ローカル: PATH_PREFIX=""
npm run serve

# GitHub Pages: PATH_PREFIX="/info"
npm run build:ghpages
```

**原因B**: 破損リンク

**解決策**:
```bash
# リンクチェック
node scripts/check-broken-images.js

# 修正
node scripts/comprehensive-image-fix.js
```

#### 3. ページネーションが生成されない

**原因**: _data/*Pages.js のロジックエラー

**解決策**:
```bash
# ログ確認
npm run build:local 2>&1 | tee build.log

# データファイル検証
node -e "console.log(require('./_data/genrePages.js'))"
```

#### 4. "Output conflict: multiple input files"

**原因**: .eleventyignore が正しく設定されていない

**解決策**:
```bash
# .eleventyignore に追加
echo "genre/" >> .eleventyignore
echo "archives/" >> .eleventyignore
echo "tetra/" >> .eleventyignore
```

#### 5. GitHub Pages で CSS/JS が読み込まれない

**原因**: PATH_PREFIX が適用されていない

**解決策**:
```bash
# テンプレートで | url フィルター使用
<link rel="stylesheet" href="{{ '/css/tetra_base.css' | url }}">

# ポストビルドスクリプト確認
npm run build:ghpages
```

#### 6. カスタムドメインに紐付けた場合は、下記を変更する
```bash
name: Deploy to GitHub Pages

on:
  push:
    branches: [develop]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build with Eleventy for GitHub Pages
        run: npm run build:ghpages # ← ここを npm run build:customにする

      - name: Deploy to gh-pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./_site
          publish_branch: gh-pages
```

### デバッグ方法

#### ビルドログ確認

```bash
# 詳細ログ
DEBUG=Eleventy* npm run build:local

# ファイル書き込みログ
npm run build:local 2>&1 | grep "Writing"
```

#### データ確認

```bash
# JSONファイル確認
cat _data/archiveEntries.json | jq '.[0]'

# JSファイル実行
node -e "const data = require('./_data/genrePages.js'); console.log(data.length, 'pages');"
```

#### 生成ファイル確認

```bash
# ファイル数
find _site/ -name "*.html" | wc -l

# 特定パターン検索
grep -r "menu_title.*ABOUT" _site/ | wc -l
```

---

## 📚 参考資料

### 公式ドキュメント

- [Eleventy Documentation](https://www.11ty.dev/docs/)
- [Nunjucks Documentation](https://mozilla.github.io/nunjucks/)
- [Sharp Documentation](https://sharp.pixelplumbing.com/)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)

### プロジェクト内ドキュメント

- `CLAUDE.md` - プロジェクト指示書
- `README.md` - 基本的な使い方
- `ARCHITECTURE.md` - 本ドキュメント

### 関連スクリプト

- `scripts/extract-*.js` - データ抽出
- `scripts/optimize-*.js` - 画像最適化
- `scripts/fix-*.js` - リンク修正
- `scripts/postbuild-add-prefix.js` - PATH_PREFIX適用

---

## 📝 変更履歴

### 2026-01-30
- ✅ Phase 1-2完了: サイズ削減とコンポーネント化
- ✅ 画像リンク修正: 3,906 → 257破損リンク（93.4%修正）
- ✅ ナビゲーション追加: 全ページネーションテンプレート
- ✅ main-navigation.njkコンポーネント作成
- 📊 最終サイズ: 203MB（_site/）

### 今後の改善案

1. **画像CDN化**: Cloudflare R2 / AWS S3で外部ホスティング
2. **レスポンシブ画像**: `<picture>` + srcset 実装
3. **バックアップ除外**: .gitignore + GitHub Actions改善
4. **TypeScript化**: スクリプトのタイプセーフティ向上
5. **E2Eテスト**: Playwright でリンク整合性チェック

---

**プロジェクト**: art space tetra
**ライセンス**: プロジェクトに準拠
