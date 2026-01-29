/**
 * genreカテゴリーのページネーションデータ生成
 * 既存HTMLのblock_box構造を維持したまま30件/ページで分割
 */

const fs = require('fs-extra');
const path = require('path');

module.exports = async function() {
  const genreDataPath = path.join(__dirname, 'genreEntries.json');

  if (!await fs.pathExists(genreDataPath)) {
    console.warn('⚠️  genreEntries.json not found. Run: node scripts/extract-genre-entries.js');
    return [];
  }

  const genreData = await fs.readJson(genreDataPath);

  const genrePages = [];
  const pageSize = 30; // MTの max_sections="30"

  for (const category of genreData) {
    const { categoryName, categorySlug, totalEntries, entries } = category;

    if (entries.length === 0) continue;

    const totalPages = Math.ceil(entries.length / pageSize);

    // 各ページのデータを生成
    for (let pageNum = 0; pageNum < totalPages; pageNum++) {
      const startIdx = pageNum * pageSize;
      const endIdx = Math.min(startIdx + pageSize, entries.length);
      const pageEntries = entries.slice(startIdx, endIdx);

      genrePages.push({
        // カテゴリー情報
        categoryName,
        categorySlug,
        categoryCount: totalEntries,

        // ページ情報
        pageNumber: pageNum,
        totalPages,
        isFirstPage: pageNum === 0,
        isLastPage: pageNum === totalPages - 1,

        // エントリー（元のHTML構造を保持）
        entries: pageEntries,

        // URL生成用
        permalink: pageNum === 0
          ? `genre/${categorySlug}/index.html`
          : `genre/${categorySlug}/page/${pageNum + 1}/index.html`
      });
    }
  }

  console.log(`📄 Generated ${genrePages.length} genre pages from ${genreData.length} categories`);

  // ページ数が2以上のカテゴリーを表示
  const multiPageCategories = genreData
    .filter(cat => Math.ceil(cat.entries.length / pageSize) > 1)
    .map(cat => ({
      name: cat.categorySlug,
      pages: Math.ceil(cat.entries.length / pageSize),
      entries: cat.totalEntries
    }));

  if (multiPageCategories.length > 0) {
    console.log(`📚 Multi-page categories:`);
    multiPageCategories.forEach(cat => {
      console.log(`   - ${cat.name}: ${cat.entries} entries → ${cat.pages} pages`);
    });
  }

  return genrePages;
};
