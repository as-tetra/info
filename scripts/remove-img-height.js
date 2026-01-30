/**
 * 全HTMLファイルからimgタグのheight属性を削除
 * width属性のみを残し、アスペクト比を保持
 */

const fs = require('fs-extra');
const glob = require('glob');

async function removeImgHeight() {
  console.log('\n🔧 Removing height attributes from img tags...\n');

  // 対象ディレクトリからHTMLファイルを検索
  const htmlFiles = glob.sync('**/*.html', {
    ignore: [
      'node_modules/**',
      '_site/**',
      'cgi-bin/**',
      'data/**',
      'data_en/**'
    ]
  });

  console.log(`📁 Found ${htmlFiles.length} HTML files\n`);

  let totalFilesModified = 0;
  let totalHeightAttrsRemoved = 0;

  for (const file of htmlFiles) {
    let content = await fs.readFile(file, 'utf-8');
    const originalContent = content;

    // imgタグからheight属性を削除
    // パターン1: height="数値"
    // パターン2: height='数値'
    // パターン3: height=数値（クォートなし）
    const heightPatterns = [
      /\s+height=["']?\d+["']?/gi,
      /\s+height=["'][^"']*["']/gi
    ];

    let fileModified = false;
    let removedCount = 0;

    heightPatterns.forEach(pattern => {
      const matches = content.match(pattern);
      if (matches) {
        removedCount += matches.length;
        content = content.replace(pattern, '');
        fileModified = true;
      }
    });

    if (fileModified) {
      await fs.writeFile(file, content, 'utf-8');
      console.log(`✅ ${file}`);
      console.log(`   → Removed ${removedCount} height attribute(s)`);
      totalFilesModified++;
      totalHeightAttrsRemoved += removedCount;
    }
  }

  console.log(`\n✅ Complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - Files processed: ${htmlFiles.length}`);
  console.log(`   - Files modified: ${totalFilesModified}`);
  console.log(`   - Height attributes removed: ${totalHeightAttrsRemoved}`);
}

removeImgHeight().catch(console.error);
