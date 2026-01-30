/**
 * tetra/index.htmlからエントリーを抽出してページネーション用データを生成
 */

const fs = require('fs-extra');
const cheerio = require('cheerio');

async function extractTetraEntries() {
  console.log('\n📖 Extracting entries from tetra/index.html...\n');

  const htmlFile = 'tetra/index.html';
  const content = await fs.readFile(htmlFile, 'utf-8');
  const $ = cheerio.load(content);

  const entries = [];

  // block_boxを抽出（menu_titleは除外）
  $('.block_box, .block_box2').each((i, elem) => {
    const $block = $(elem);

    // タイトルblock_boxはスキップ
    if ($block.find('.menu_title').length > 0) return;

    // 日付を抽出
    const dateText = $block.find('.date, .date_past').text().trim();
    const isPast = $block.find('.date_past').length > 0;

    // タイトルを抽出
    const titleJp = $block.find('.jp h1 a').text().trim();
    const titleEn = $block.find('.en h1 a').first().text().trim();

    // URLを抽出
    const url = $block.find('h1 a').attr('href');

    // 画像情報を抽出 - 日本語ファイル名をNFC正規化（濁点問題対策）
    let imgSrc = $block.find('img').attr('src');
    if (imgSrc) {
      imgSrc = imgSrc.normalize('NFC');
    }

    const imgAlt = $block.find('img').attr('alt');
    const imgWidth = $block.find('img').attr('width');

    // 本文を抽出
    const bodyJp = $block.find('.jp p').html();
    const bodyEn = $block.find('.en p').html();

    if (titleJp || titleEn) {
      entries.push({
        date: dateText,
        isPast,
        titleJp,
        titleEn,
        url,
        imgSrc,
        imgAlt,
        imgWidth,
        bodyJp,
        bodyEn
      });
    }
  });

  console.log(`✅ Extracted ${entries.length} entries\n`);

  // 日付でソート（新しい順）
  entries.sort((a, b) => {
    // 日付を比較可能な形式に変換
    const dateA = a.date.replace(/\./g, '').replace(/-/g, '');
    const dateB = b.date.replace(/\./g, '').replace(/-/g, '');
    return dateB.localeCompare(dateA);
  });

  // ページネーション用データを生成
  const pageSize = 30; // MT標準の30件
  const tetraPages = [];

  for (let i = 0; i < entries.length; i += pageSize) {
    const pageEntries = entries.slice(i, i + pageSize);
    const pageNumber = Math.floor(i / pageSize);
    const totalPages = Math.ceil(entries.length / pageSize);

    const permalink = pageNumber === 0
      ? 'tetra/index.html'
      : `tetra/page/${pageNumber + 1}/index.html`;

    tetraPages.push({
      pageNumber,
      totalPages,
      entryCount: entries.length,
      isFirstPage: pageNumber === 0,
      isLastPage: pageNumber === totalPages - 1,
      entries: pageEntries,
      permalink
    });
  }

  console.log(`📄 Generated ${tetraPages.length} pages:\n`);
  tetraPages.forEach((page, i) => {
    console.log(`   Page ${i + 1}: ${page.entries.length} entries`);
  });

  // データファイルに保存
  const outputFile = '_data/tetraPages.js';
  const jsContent = `module.exports = ${JSON.stringify(tetraPages, null, 2)};`;
  await fs.writeFile(outputFile, jsContent, 'utf-8');

  console.log(`\n✅ Saved to ${outputFile}`);
  console.log(`\n💡 Next steps:`);
  console.log(`   1. Create tetra-paginated/index.njk template`);
  console.log(`   2. Add tetra/ to .eleventyignore`);
  console.log(`   3. npm run build:local`);
}

extractTetraEntries().catch(console.error);
