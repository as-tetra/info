/**
 * Extract Entries from HTML and XML
 *
 * 機能:
 * - atom.xml から記事データを抽出
 * - 既存の index.html (旧 index.php) から記事ブロックを抽出
 * - 重複を排除してマージ
 * - 日付順にソート（新しい順）
 * - _data/entries.json として保存
 *
 * 使用方法:
 *   node scripts/extract-entries.js
 *
 * 出力:
 *   _data/entries.json - Eleventy pagination 用のデータ
 */

const fs = require('fs-extra');
const path = require('path');
const { glob } = require('glob');
const cheerio = require('cheerio');
const xml2js = require('xml2js');

// ========== 設定 ==========
const CONFIG = {
  // 出力先
  outputFile: '_data/entries.json',

  // atom.xml のパス
  atomXmlPath: 'data/atom.xml',

  // HTML から抽出する対象（index.html, index.php）
  htmlPatterns: [
    '2004/index.html',
    '2005/index.html',
    '2006/index.html',
    '2007/index.html',
    '2008/index.html',
    '2009/index.html',
    'archives/*/index.html',
  ],

  // 記事ブロックのセレクタ
  entrySelector: '.block1',

  // タイトルのセレクタ（記事ブロック内）
  titleSelector: 'h1 a',

  // 本文のセレクタ（記事ブロック内）
  bodySelector: '.m_body',
};

// ========== 統計情報 ==========
const stats = {
  fromXml: 0,
  fromHtml: 0,
  duplicates: 0,
  total: 0,
};

// ========== ユーティリティ ==========

const colors = {
  green: (text) => `\x1b[32m${text}\x1b[0m`,
  yellow: (text) => `\x1b[33m${text}\x1b[0m`,
  cyan: (text) => `\x1b[36m${text}\x1b[0m`,
  dim: (text) => `\x1b[2m${text}\x1b[0m`,
};

/**
 * 日付文字列をパース（様々な形式に対応）
 */
function parseDate(dateStr) {
  if (!dateStr) return null;

  // ISO 8601 形式
  if (dateStr.includes('T')) {
    return new Date(dateStr);
  }

  // 日本語形式: 2004.12.19(sun) や 2004.11.23-12.12
  const jpMatch = dateStr.match(/(\d{4})\.(\d{1,2})\.(\d{1,2})/);
  if (jpMatch) {
    return new Date(parseInt(jpMatch[1]), parseInt(jpMatch[2]) - 1, parseInt(jpMatch[3]));
  }

  // ファイル名から抽出: 041219123252.html → 2004-12-19
  const fileMatch = dateStr.match(/^(\d{2})(\d{2})(\d{2})/);
  if (fileMatch) {
    const year = parseInt(fileMatch[1]) + 2000;
    const month = parseInt(fileMatch[2]) - 1;
    const day = parseInt(fileMatch[3]);
    return new Date(year, month, day);
  }

  return null;
}

/**
 * テキストをクリーンアップ
 */
function cleanText(text) {
  if (!text) return '';
  return text
    .replace(/\s+/g, ' ')
    .replace(/\n+/g, ' ')
    .trim();
}

/**
 * HTML タグを除去して抜粋を作成
 */
function createExcerpt(html, maxLength = 200) {
  if (!html) return '';
  const text = html
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength) + '...';
}

/**
 * URL から年を抽出
 */
function extractYearFromUrl(url) {
  const match = url.match(/\/(\d{4})\//);
  return match ? parseInt(match[1]) : null;
}

/**
 * atom.xml から記事を抽出
 */
async function extractFromAtomXml() {
  const entries = [];

  if (!await fs.pathExists(CONFIG.atomXmlPath)) {
    console.log(colors.yellow(`⚠️  ${CONFIG.atomXmlPath} not found, skipping XML extraction`));
    return entries;
  }

  console.log(colors.cyan(`📄 Reading ${CONFIG.atomXmlPath}...`));

  const xmlContent = await fs.readFile(CONFIG.atomXmlPath, 'utf-8');
  const parser = new xml2js.Parser({ explicitArray: false });
  const result = await parser.parseStringPromise(xmlContent);

  const feedEntries = result.feed.entry;
  if (!feedEntries) return entries;

  const entryArray = Array.isArray(feedEntries) ? feedEntries : [feedEntries];

  for (const entry of entryArray) {
    const link = entry.link;
    let url = '';

    if (Array.isArray(link)) {
      const altLink = link.find(l => l.$ && l.$.rel === 'alternate');
      url = altLink ? altLink.$.href : link[0].$.href;
    } else if (link && link.$) {
      url = link.$.href;
    }

    // URL を正規化
    url = url.replace(/^https?:\/\/(www\.)?as-tetra\.info/, '');

    const categories = [];
    if (entry.category) {
      const cats = Array.isArray(entry.category) ? entry.category : [entry.category];
      for (const cat of cats) {
        if (cat.$ && cat.$.term) {
          categories.push(cat.$.term);
        }
      }
    }

    // content を取得
    let content = '';
    if (entry.content) {
      if (typeof entry.content === 'string') {
        content = entry.content;
      } else if (entry.content._) {
        content = entry.content._;
      }
    }

    entries.push({
      title: cleanText(entry.title),
      url: url,
      date: entry.published || entry.updated,
      dateObj: parseDate(entry.published || entry.updated),
      summary: cleanText(entry.summary) || createExcerpt(content),
      categories: categories.filter(c => !c.match(/^\d{4}$/)), // 年だけのカテゴリは除外
      year: extractYearFromUrl(url),
      source: 'xml',
    });
  }

  stats.fromXml = entries.length;
  console.log(colors.green(`   ✅ Extracted ${entries.length} entries from XML`));

  return entries;
}

/**
 * HTML ファイルから記事を抽出
 */
async function extractFromHtml() {
  const entries = [];

  console.log(colors.cyan('\n📄 Extracting from HTML files...'));

  for (const pattern of CONFIG.htmlPatterns) {
    const files = await glob(pattern, { nodir: true });

    for (const file of files) {
      if (!await fs.pathExists(file)) continue;

      const content = await fs.readFile(file, 'utf-8');
      const $ = cheerio.load(content);

      // ディレクトリから年を抽出
      const yearMatch = file.match(/(?:^|\/)(20\d{2}|archives\/20\d{2})\//);
      const defaultYear = yearMatch ? parseInt(yearMatch[1].replace('archives/', '')) : null;

      $(CONFIG.entrySelector).each((i, el) => {
        const $entry = $(el);

        // タイトルとリンクを取得
        const $titleLink = $entry.find(CONFIG.titleSelector);
        const title = cleanText($titleLink.text());
        let url = $titleLink.attr('href') || '';

        if (!title || !url) return;

        // URL を正規化
        url = url.replace(/^https?:\/\/(www\.)?as-tetra\.info/, '');

        // 本文を取得
        const $body = $entry.find(CONFIG.bodySelector);
        const bodyHtml = $body.html() || '';
        const summary = createExcerpt(bodyHtml);

        // 日付を本文から抽出
        const bodyText = $body.text();
        const dateMatch = bodyText.match(/(\d{4}\.\d{1,2}\.\d{1,2})/);
        let dateStr = dateMatch ? dateMatch[1] : null;

        // ファイル名から日付を推測
        if (!dateStr) {
          const fileMatch = url.match(/\/(\d{6,})/);
          if (fileMatch) {
            dateStr = fileMatch[1];
          }
        }

        const dateObj = parseDate(dateStr);
        const year = extractYearFromUrl(url) || defaultYear;

        entries.push({
          title: title,
          url: url,
          date: dateObj ? dateObj.toISOString() : null,
          dateObj: dateObj,
          summary: summary,
          categories: [],
          year: year,
          source: 'html',
        });
      });

      const count = $(CONFIG.entrySelector).length;
      if (count > 0) {
        console.log(colors.dim(`   ${file}: ${count} entries`));
      }
    }
  }

  stats.fromHtml = entries.length;
  console.log(colors.green(`   ✅ Extracted ${entries.length} entries from HTML`));

  return entries;
}

/**
 * エントリをマージして重複を排除
 */
function mergeAndDeduplicate(xmlEntries, htmlEntries) {
  const urlMap = new Map();

  // XML からのエントリを優先（より詳細な情報を持つ）
  for (const entry of xmlEntries) {
    if (entry.url) {
      urlMap.set(entry.url, entry);
    }
  }

  // HTML からのエントリを追加（重複しない場合のみ）
  for (const entry of htmlEntries) {
    if (entry.url && !urlMap.has(entry.url)) {
      urlMap.set(entry.url, entry);
    } else if (entry.url) {
      stats.duplicates++;
    }
  }

  return Array.from(urlMap.values());
}

/**
 * エントリをソート（新しい順）
 */
function sortEntries(entries) {
  return entries.sort((a, b) => {
    // 日付がある場合は日付でソート
    if (a.dateObj && b.dateObj) {
      return b.dateObj - a.dateObj;
    }
    // 日付がない場合は年でソート
    if (a.year && b.year) {
      return b.year - a.year;
    }
    // それ以外はタイトルでソート
    return (a.title || '').localeCompare(b.title || '');
  });
}

/**
 * 年別にグループ化
 */
function groupByYear(entries) {
  const groups = {};

  for (const entry of entries) {
    const year = entry.year || 'unknown';
    if (!groups[year]) {
      groups[year] = [];
    }
    groups[year].push(entry);
  }

  return groups;
}

/**
 * メイン処理
 */
async function main() {
  console.log('========================================');
  console.log('📚 Extract Entries from HTML and XML');
  console.log('========================================\n');

  // XML から抽出
  const xmlEntries = await extractFromAtomXml();

  // HTML から抽出
  const htmlEntries = await extractFromHtml();

  // マージと重複排除
  console.log(colors.cyan('\n🔄 Merging and deduplicating...'));
  let entries = mergeAndDeduplicate(xmlEntries, htmlEntries);

  // ソート
  entries = sortEntries(entries);

  // dateObj を削除（JSON にシリアライズできないため）
  entries = entries.map(({ dateObj, ...rest }) => rest);

  stats.total = entries.length;

  // 年別にグループ化した統計
  const groups = groupByYear(entries);

  // 出力ディレクトリを作成
  await fs.ensureDir(path.dirname(CONFIG.outputFile));

  // JSON として保存
  await fs.writeJson(CONFIG.outputFile, entries, { spaces: 2 });

  // 結果サマリー
  console.log('\n========================================');
  console.log('📊 Summary');
  console.log('========================================');
  console.log(`From XML:     ${stats.fromXml}`);
  console.log(`From HTML:    ${stats.fromHtml}`);
  console.log(`Duplicates:   ${stats.duplicates}`);
  console.log(`Total:        ${stats.total}`);
  console.log('----------------------------------------');
  console.log('By year:');
  for (const year of Object.keys(groups).sort().reverse()) {
    console.log(`  ${year}: ${groups[year].length} entries`);
  }
  console.log('========================================');

  console.log(colors.green(`\n✅ Saved to ${CONFIG.outputFile}`));
  console.log(colors.cyan('\n📌 Next steps:'));
  console.log('   1. npm install  (to install cheerio and xml2js)');
  console.log('   2. npm run serve');
  console.log('   3. Check /archives/ for paginated archives');
}

// 実行
main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
