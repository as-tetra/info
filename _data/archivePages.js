/**
 * 年別アーカイブ ページネーションデータ生成
 * MTのMTPaginate (max_sections="30") 相当の静的ページを生成
 */

const fs = require('fs-extra');
const path = require('path');

module.exports = async function () {
  // アーカイブエントリーデータを読み込み
  const entriesPath = path.join(__dirname, 'archiveEntries.json');

  if (!await fs.pathExists(entriesPath)) {
    console.warn('⚠️  archiveEntries.json not found');
    return [];
  }

  const archiveData = await fs.readJson(entriesPath);

  // ページ分割データを生成
  const archivePages = [];
  const pageSize = 30; // MTの max_sections="30"

  for (const { year, entries } of archiveData) {
    const totalPages = Math.ceil(entries.length / pageSize);

    // 各ページのデータを生成
    for (let pageNum = 0; pageNum < totalPages; pageNum++) {
      const startIdx = pageNum * pageSize;
      const endIdx = Math.min(startIdx + pageSize, entries.length);
      const pageEntries = entries.slice(startIdx, endIdx);

      archivePages.push({
        // 年情報
        year,
        entryCount: entries.length,

        // ページ情報
        pageNumber: pageNum,
        totalPages,
        isFirstPage: pageNum === 0,
        isLastPage: pageNum === totalPages - 1,

        // エントリー
        entries: pageEntries,

        // URL生成用
        permalink: pageNum === 0
          ? `archives/${year}/index.html`
          : `archives/${year}/page/${pageNum + 1}/index.html`
      });
    }
  }

  // 年でソート（降順）
  archivePages.sort((a, b) => {
    const yearDiff = parseInt(b.year) - parseInt(a.year);
    if (yearDiff !== 0) return yearDiff;
    return a.pageNumber - b.pageNumber;
  });

  console.log(`📄 Generated ${archivePages.length} archive pages from ${archiveData.length} years`);

  // 複数ページの年を表示
  const multiPageYears = archiveData.filter(({ entries }) => entries.length > 30);
  if (multiPageYears.length > 0) {
    console.log(`📚 Multi-page years:`);
    multiPageYears.forEach(({ year, entries }) => {
      const pages = Math.ceil(entries.length / pageSize);
      console.log(`   - ${year}: ${entries.length} entries → ${pages} pages`);
    });
  }

  return archivePages;
};
