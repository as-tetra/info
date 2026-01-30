/**
 * 年別アーカイブからblock_boxエントリーを抽出
 * archives/YYYY/index.html から情報を抽出してJSONに保存
 */

const fs = require('fs-extra');
const path = require('path');
const cheerio = require('cheerio');
const glob = require('glob');

async function extractArchiveEntries() {
  const archiveFiles = glob.sync('archives/*/index.html');

  console.log(`\n📂 Found ${archiveFiles.length} archive index files`);

  const archiveData = [];

  for (const filePath of archiveFiles) {
    const year = path.basename(path.dirname(filePath));
    console.log(`\n🗓️  Processing year ${year}...`);

    const html = await fs.readFile(filePath, 'utf-8');
    const $ = cheerio.load(html);

    const entries = [];

    // block_boxを抽出（menu_titleは除外）
    $('.block_box').each((i, elem) => {
      const $block = $(elem);

      // menu_titleブロックをスキップ
      if ($block.find('.menu_title').length > 0) {
        return;
      }

      // エントリー情報を抽出
      const date = $block.find('.date, .date_past').text().trim();
      const titleJp = $block.find('.jp h1 a').text().trim();
      const titleEn = $block.find('.en h1 a').first().text().trim();
      const url = $block.find('a').first().attr('href');

      // 画像情報 - 日本語ファイル名をNFC正規化（濁点問題対策）
      let imgSrc = $block.find('img').attr('src');
      if (imgSrc) {
        imgSrc = imgSrc.normalize('NFC');
      }

      const imgAlt = $block.find('img').attr('alt');
      const imgWidth = $block.find('img').attr('width');

      // date_pastクラスの有無
      const isPast = $block.find('.date_past').length > 0;

      // 本文（jpとenの両方）
      const bodyJp = $block.find('.jp p').map((i, el) => $(el).html()).get().join('\n');
      const bodyEn = $block.find('.en p').map((i, el) => $(el).html()).get().join('\n');

      entries.push({
        date,
        titleJp,
        titleEn,
        url,
        imgSrc,
        imgAlt,
        imgWidth,
        isPast,
        bodyJp,
        bodyEn,
        html: $.html($block)
      });
    });

    console.log(`   → ${entries.length} entries extracted`);

    archiveData.push({
      year,
      entries
    });
  }

  // データをJSONに保存
  const outputPath = path.join(__dirname, '../_data/archiveEntries.json');
  await fs.writeJson(outputPath, archiveData, { spaces: 2 });

  // 統計情報
  const totalEntries = archiveData.reduce((sum, year) => sum + year.entries.length, 0);
  console.log(`\n✅ Extraction complete!`);
  console.log(`📊 Total: ${totalEntries} entries from ${archiveData.length} years`);
  console.log(`💾 Saved to: ${outputPath}`);

  // 各年の詳細
  console.log(`\n📈 Entries per year:`);
  archiveData.forEach(({ year, entries }) => {
    const pages = Math.ceil(entries.length / 30);
    console.log(`   - ${year}: ${entries.length} entries → ${pages} page(s)`);
  });
}

extractArchiveEntries().catch(console.error);
