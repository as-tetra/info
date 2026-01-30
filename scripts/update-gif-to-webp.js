/**
 * GIF → WebP リンク更新
 * WebPに変換されたGIFへのリンクを更新
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

async function updateGifToWebP() {
  console.log('\n🔄 Updating GIF links to WebP...\n');

  // WebPに変換されたファイルを検索
  const webpFiles = glob.sync('upload/**/*.webp');
  console.log(`📁 Found ${webpFiles.length} WebP files\n`);

  // 対応するGIFが存在するWebPファイルのみを対象
  const conversions = [];
  for (const webpFile of webpFiles) {
    const gifFile = webpFile.replace(/\.webp$/, '.gif');
    if (await fs.pathExists(gifFile)) {
      conversions.push({
        gif: gifFile,
        webp: webpFile
      });
    }
  }

  console.log(`🎯 Found ${conversions.length} GIF→WebP conversions:\n`);
  conversions.forEach(({ gif, webp }) => {
    console.log(`   ${path.basename(gif)} → ${path.basename(webp)}`);
  });
  console.log('');

  // HTMLファイルを検索
  const htmlFiles = glob.sync('**/*.html', {
    ignore: ['node_modules/**', '_site/**', 'cgi-bin/**', 'data/**', 'data_en/**']
  });

  let totalFilesModified = 0;
  let totalLinksUpdated = 0;

  for (const htmlFile of htmlFiles) {
    let content = await fs.readFile(htmlFile, 'utf-8');
    const originalContent = content;
    let fileModified = false;

    // 各変換されたGIFについてリンクを更新
    for (const { gif, webp } of conversions) {
      const gifBasename = path.basename(gif);
      const webpBasename = path.basename(webp);

      // パターン: src="/upload/.../filename.gif"
      const gifPattern = new RegExp(`(<img[^>]*src=["'])([^"']*/${gifBasename.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})(["'][^>]*>)`, 'gi');

      const matches = content.match(gifPattern);
      if (matches) {
        content = content.replace(gifPattern, (match, prefix, srcPath, suffix) => {
          const newPath = srcPath.replace(new RegExp(gifBasename + '$'), webpBasename);
          totalLinksUpdated++;
          return prefix + newPath + suffix;
        });
        fileModified = true;
      }
    }

    if (fileModified) {
      await fs.writeFile(htmlFile, content, 'utf-8');
      totalFilesModified++;
    }
  }

  console.log(`\n✅ Complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - HTML files scanned: ${htmlFiles.length}`);
  console.log(`   - Files modified: ${totalFilesModified}`);
  console.log(`   - Links updated: ${totalLinksUpdated}`);
  console.log(`\n💡 Old GIF files can now be safely deleted if needed`);
}

updateGifToWebP().catch(console.error);
