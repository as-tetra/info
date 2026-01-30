/**
 * 全ファイル内の内部PHPリンクをHTMLに置き換え
 * - sitemap.xml
 * - *.json
 * - *.html
 *
 * 外部URLのPHPリンク（http://example.com/page.php）は変更しない
 */

const fs = require('fs-extra');
const glob = require('glob');

async function replacePhpLinksWithHtml() {
  console.log('\n🔧 Replacing internal .php links with .html...\n');

  // 対象ファイルを検索
  const files = glob.sync('**/*.{xml,json,html}', {
    ignore: [
      'node_modules/**',
      '_site/**',
      'cgi-bin/**',
      'data/**',
      'data_en/**'
    ]
  });

  console.log(`📁 Found ${files.length} files to process\n`);

  let totalFilesModified = 0;
  let totalReplacements = 0;

  for (const file of files) {
    let content = await fs.readFile(file, 'utf-8');
    const originalContent = content;

    // 内部リンクの.phpを.htmlに置き換えるパターン
    const patterns = [
      // href="/path/to/file.php" → href="/path/to/file.html"
      { from: /href="(\/[^"]*?)\.php"/g, to: 'href="$1.html"' },
      // href='/path/to/file.php' → href='/path/to/file.html'
      { from: /href='(\/[^']*?)\.php'/g, to: "href='$1.html'" },
      // <loc>/path/to/file.php</loc> → <loc>/path/to/file.html</loc> (sitemap用)
      { from: /<loc>(\/[^<]*?)\.php<\/loc>/g, to: '<loc>$1.html</loc>' },
      // "url": "/path/to/file.php" → "url": "/path/to/file.html" (JSON用)
      { from: /"url":\s*"(\/[^"]*?)\.php"/g, to: '"url": "$1.html"' },
      // src="/path/to/file.php" → src="/path/to/file.html" (念のため)
      { from: /src="(\/[^"]*?)\.php"/g, to: 'src="$1.html"' },
    ];

    let fileModified = false;
    let replacementCount = 0;

    patterns.forEach(({ from, to }) => {
      const matches = content.match(from);
      if (matches) {
        replacementCount += matches.length;
        content = content.replace(from, to);
        fileModified = true;
      }
    });

    if (fileModified) {
      await fs.writeFile(file, content, 'utf-8');
      console.log(`✅ ${file}`);
      console.log(`   → ${replacementCount} .php link(s) replaced with .html`);
      totalFilesModified++;
      totalReplacements += replacementCount;
    }
  }

  console.log(`\n✅ Complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - Files processed: ${files.length}`);
  console.log(`   - Files modified: ${totalFilesModified}`);
  console.log(`   - Total replacements: ${totalReplacements}`);

  if (totalFilesModified > 0) {
    console.log(`\n💡 Next steps:`);
    console.log(`   1. Rebuild the site: npm run build:local`);
    console.log(`   2. Verify all links work correctly`);
    console.log(`   3. Test on localhost:8080`);
  }
}

replacePhpLinksWithHtml().catch(console.error);
