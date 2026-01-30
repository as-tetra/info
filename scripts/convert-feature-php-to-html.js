/**
 * special/feature/ 配下のPHPファイルをHTMLに変換
 * 1. .php → .html にリネーム
 * 2. 絶対URL (http://www.as-tetra.info/) を相対パスに変換
 * 3. index.html 内の .php リンクを .html に更新
 */

const fs = require('fs-extra');
const path = require('path');
const glob = require('glob');

async function convertFeaturePhpToHtml() {
  console.log('\n🔄 Converting special/feature PHP files to HTML...\n');

  // 1. PHPファイルを検索
  const phpFiles = glob.sync('special/feature/**/*.php');
  console.log(`📁 Found ${phpFiles.length} PHP files\n`);

  const conversions = [];

  for (const phpFile of phpFiles) {
    const htmlFile = phpFile.replace(/\.php$/, '.html');

    console.log(`📝 ${phpFile} → ${htmlFile}`);

    // ファイル内容を読み込み
    let content = await fs.readFile(phpFile, 'utf-8');

    // 絶対URLを相対パスに変換
    const urlReplacements = [
      // CSS/JS/画像の絶対URL
      { from: /http:\/\/www\.as-tetra\.info\//g, to: '/' },
      // リンクの絶対URL
      { from: /href="http:\/\/www\.as-tetra\.info\//g, to: 'href="/' },
      { from: /src="http:\/\/www\.as-tetra\.info\//g, to: 'src="/' },
      // cssPath の絶対URL
      { from: /cssPath:\s*'http:\/\/www\.as-tetra\.info\//g, to: "cssPath: '/" },
      { from: /cssPath:\s*"http:\/\/www\.as-tetra\.info\//g, to: 'cssPath: "/' },
    ];

    let replacementCount = 0;
    urlReplacements.forEach(({ from, to }) => {
      const matches = content.match(from);
      if (matches) {
        replacementCount += matches.length;
        content = content.replace(from, to);
      }
    });

    console.log(`   → ${replacementCount} absolute URLs converted to relative paths`);

    // HTMLファイルとして保存
    await fs.writeFile(htmlFile, content, 'utf-8');
    console.log(`   ✅ Created ${htmlFile}\n`);

    conversions.push({ phpFile, htmlFile });
  }

  // 2. index.htmlを更新（.php → .html）
  const indexFile = 'special/feature/index.html';
  if (await fs.pathExists(indexFile)) {
    console.log(`📝 Updating ${indexFile}...`);
    let indexContent = await fs.readFile(indexFile, 'utf-8');

    // .phpリンクを.htmlに変更
    const phpLinkPattern = /href="([^"]+)\.php"/g;
    const phpLinkMatches = indexContent.match(phpLinkPattern);
    if (phpLinkMatches) {
      console.log(`   → Found ${phpLinkMatches.length} .php links`);
      indexContent = indexContent.replace(phpLinkPattern, 'href="$1.html"');
      await fs.writeFile(indexFile, indexContent, 'utf-8');
      console.log(`   ✅ Updated all .php links to .html\n`);
    } else {
      console.log(`   ℹ️  No .php links found\n`);
    }
  }

  // 3. サマリー
  console.log(`\n✅ Conversion complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - ${conversions.length} PHP files converted to HTML`);
  console.log(`   - index.html updated with .html links`);
  console.log(`\n💡 Next steps:`);
  console.log(`   1. Test the converted HTML files in browser`);
  console.log(`   2. Verify all links work correctly`);
  console.log(`   3. Delete .php files: rm special/feature/**/*.php`);
}

convertFeaturePhpToHtml().catch(console.error);
