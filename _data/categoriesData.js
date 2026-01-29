/**
 * カテゴリーアーカイブデータ生成
 * MTのカテゴリーアーカイブに相当する静的データを生成
 */

const fs = require('fs-extra');
const path = require('path');

module.exports = async function() {
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
      return; // カテゴリーなしのエントリーはスキップ
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

  // カテゴリーデータを配列に変換し、エントリー数で降順ソート
  const categoriesArray = Array.from(categoriesMap.entries()).map(([name, entries]) => {
    // URLスラッグを生成（MTのベースネーム相当）
    const slug = name
      .toLowerCase()
      .replace(/[^\w\s-]/g, '') // 特殊文字除去
      .replace(/\s+/g, '_')      // スペースをアンダースコアに
      .replace(/_+/g, '_')       // 連続アンダースコアを1つに
      .replace(/^_|_$/g, '');    // 前後のアンダースコア除去

    // エントリーを日付で降順ソート
    const sortedEntries = entries.sort((a, b) => {
      const dateA = a.date ? new Date(a.date) : new Date(0);
      const dateB = b.date ? new Date(b.date) : new Date(0);
      return dateB - dateA;
    });

    return {
      name,           // カテゴリー名（表示用）
      slug,           // URLスラッグ
      count: sortedEntries.length,
      entries: sortedEntries
    };
  });

  // エントリー数で降順ソート
  categoriesArray.sort((a, b) => b.count - a.count);

  console.log(`📂 Generated ${categoriesArray.length} categories:`);
  categoriesArray.slice(0, 10).forEach(cat => {
    console.log(`   - ${cat.name} (${cat.count} entries) → /${cat.slug}/`);
  });

  return categoriesArray;
};
