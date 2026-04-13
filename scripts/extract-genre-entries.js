/**
 * 既存のgenre/カテゴリー/index.htmlから block_box を抽出
 * ページネーション用データを生成
 */

const fs = require('fs-extra');
const path = require('path');
const cheerio = require('cheerio');
const { glob } = require('glob');

async function extractGenreEntries() {
  const genreDir = path.join(process.cwd(), 'genre');

  // genre/*/index.html を検索
  const genreFiles = await glob('genre/*/index.html', {
    nodir: true
  });

  console.log(`📂 Found ${genreFiles.length} genre files`);

  const allGenreData = [];

  for (const filePath of genreFiles) {
    const categorySlug = path.basename(path.dirname(filePath));
    const html = await fs.readFile(filePath, 'utf-8');
    const $ = cheerio.load(html);

    // block_box を抽出（最初のヘッダーブロックは除外）
    const entries = [];

    $('.block_box').each((i, elem) => {
      const $block = $(elem);

      // 最初のblock_boxはカテゴリータイトルなのでスキップ
      if ($block.find('.menu_title').length > 0) {
        return;
      }

      // 検索フォーム（block_box double）をスキップ
      if ($block.hasClass('double') || $block.find('#cse-search-box').length > 0) {
        return;
      }

      // sub_menu内のblock_boxをスキップ
      if ($block.parents('.sub_menu').length > 0) {
        return;
      }

      // エントリー情報を抽出
      const date = $block.find('.date, .date_past').text().trim();
      const titleJp = $block.find('.jp h1 a').text().trim();
      const titleEn = $block.find('.en h1 a').text().trim();
      const url = $block.find('a').first().attr('href');

      // 画像パス - 日本語ファイル名をNFC正規化（濁点問題対策）
      let imgSrc = $block.find('img').attr('src');
      if (imgSrc) {
        imgSrc = imgSrc.normalize('NFC');
      }

      const imgAlt = $block.find('img').attr('alt');
      const imgWidth = $block.find('img').attr('width');

      // HTMLブロックを保存（後でそのまま出力するため）
      entries.push({
        date,
        titleJp: titleJp || titleEn,
        titleEn: titleEn || titleJp,
        url,
        imgSrc,
        imgAlt,
        imgWidth,
        html: $.html($block), // 元のHTML構造を保持
        isPast: $block.find('.date_past').length > 0
      });
    });

    console.log(`   ${categorySlug}: ${entries.length} entries`);

    // カテゴリー名を取得
    const categoryName = $('.menu_title').first().text().trim() || categorySlug;

    allGenreData.push({
      categoryName,
      categorySlug,
      totalEntries: entries.length,
      entries
    });
  }

  // データをJSONファイルに保存
  const outputPath = path.join(process.cwd(), '_data', 'genreEntries.json');
  await fs.writeJson(outputPath, allGenreData, { spaces: 2 });

  console.log(`\n✅ Saved to _data/genreEntries.json`);
  console.log(`📊 Total categories: ${allGenreData.length}`);
  console.log(`📄 Total entries: ${allGenreData.reduce((sum, cat) => sum + cat.totalEntries, 0)}`);

  return allGenreData;
}

// 実行
if (require.main === module) {
  extractGenreEntries().catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
}

module.exports = extractGenreEntries;
