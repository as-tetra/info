/**
 * カテゴリーアーカイブ ページネーションデータ生成
 * MTのMTPaginate (max_sections="30") 相当の静的ページを生成
 */

const fs = require('fs-extra');
const path = require('path');

module.exports = async function () {
  // エントリーデータを読み込み
  const entriesPath = path.join(__dirname, 'entries.json');

  if (!await fs.pathExists(entriesPath)) {
    console.warn('⚠️  entries.json not found');
    return [];
  }

  const entries = await fs.readJson(entriesPath);

  // カテゴリーごとにエントリーをグループ化
  const categoriesMap = new Map();

  entries.forEach(entry => {
    if (!entry.categories || entry.categories.length === 0) {
      return;
    }

    entry.categories.forEach(category => {
      // "NOT 事務情報" のような除外カテゴリーをスキップ
      if (category.startsWith('NOT ')) {
        return;
      }

      if (!categoriesMap.has(category)) {
        categoriesMap.set(category, []);
      }
      categoriesMap.get(category).push(entry);
    });
  });

  // ページ分割データを生成
  const categoryPages = [];
  const pageSize = 30; // MTの max_sections="30"

  for (const [categoryName, categoryEntries] of categoriesMap.entries()) {
    // URLスラッグを生成
    const slug = categoryName
      .toLowerCase()
      .replace(/[^\w\s-]/g, '')
      .replace(/\s+/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_|_$/g, '');

    // エントリーを日付で降順ソート
    const sortedEntries = categoryEntries.sort((a, b) => {
      const dateA = a.date ? new Date(a.date) : new Date(0);
      const dateB = b.date ? new Date(b.date) : new Date(0);
      return dateB - dateA;
    });

    const totalPages = Math.ceil(sortedEntries.length / pageSize);

    // 各ページのデータを生成
    for (let pageNum = 0; pageNum < totalPages; pageNum++) {
      const startIdx = pageNum * pageSize;
      const endIdx = Math.min(startIdx + pageSize, sortedEntries.length);
      const pageEntries = sortedEntries.slice(startIdx, endIdx);

      categoryPages.push({
        // カテゴリー情報
        categoryName,
        categorySlug: slug,
        categoryCount: sortedEntries.length,

        // ページ情報
        pageNumber: pageNum,
        totalPages,
        isFirstPage: pageNum === 0,
        isLastPage: pageNum === totalPages - 1,

        // エントリー
        entries: pageEntries,

        // URL生成用
        permalink: pageNum === 0
          ? `${slug}/index.html`
          : `${slug}/page/${pageNum + 1}/index.html`
      });
    }
  }

  // カテゴリー名でソート
  categoryPages.sort((a, b) => {
    if (a.categoryName < b.categoryName) return -1;
    if (a.categoryName > b.categoryName) return 1;
    return a.pageNumber - b.pageNumber;
  });

  console.log(`📄 Generated ${categoryPages.length} category pages from ${categoriesMap.size} categories`);

  // 各カテゴリーの情報を表示
  const categoryCounts = new Map();
  categoryPages.forEach(page => {
    if (!categoryCounts.has(page.categoryName)) {
      categoryCounts.set(page.categoryName, page.totalPages);
    }
  });

  console.log(`📂 Categories:`);
  Array.from(categoryCounts.entries()).slice(0, 10).forEach(([name, pages]) => {
    console.log(`   - ${name}: ${pages} page(s)`);
  });

  return categoryPages;
};
