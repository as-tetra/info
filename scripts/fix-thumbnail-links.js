/**
 * サムネイルリンク修正ツール
 * 削除済みの-thumb.*ファイルへのリンクを元の画像ファイルに置換
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

async function fixThumbnailLinks() {
  console.log('\n🔧 Fixing thumbnail links...\n');

  // 対象HTMLファイルを検索
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
  let totalLinksFixed = 0;
  const stats = {
    replacedWithOriginal: 0,
    originalNotFound: 0,
    alreadyCorrect: 0
  };

  for (const file of htmlFiles) {
    let content = await fs.readFile(file, 'utf-8');
    const originalContent = content;

    // -thumb.* パターンをマッチ
    // src="/upload/YYYY/filename-thumb.ext" または src="upload/YYYY/filename-thumb.ext"
    const thumbPattern = /(<img[^>]*src=["'])([^"']*?)(-thumb)(\.[^"'\.]+)(["'][^>]*>)/gi;

    let fileModified = false;
    let replacements = 0;

    // 各マッチを処理
    content = content.replace(thumbPattern, (match, prefix, basePath, thumbSuffix, ext, suffix) => {
      // 元の画像パス（-thumbを削除）
      const originalPath = basePath + ext;

      // パスの正規化（先頭の / を削除）
      const normalizedPath = originalPath.startsWith('/') ? originalPath.substring(1) : originalPath;

      // 元の画像ファイルが存在するか確認
      if (fs.existsSync(normalizedPath)) {
        stats.replacedWithOriginal++;
        replacements++;
        return prefix + originalPath + suffix;
      } else {
        stats.originalNotFound++;
        console.log(`   ⚠️  Original not found: ${normalizedPath}`);
        return match; // 元のまま
      }
    });

    if (content !== originalContent) {
      await fs.writeFile(file, content, 'utf-8');
      console.log(`✅ ${file}`);
      console.log(`   → Fixed ${replacements} thumbnail link(s)`);
      totalFilesModified++;
      totalLinksFixed += replacements;
      fileModified = true;
    }
  }

  console.log(`\n✅ Complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - Files processed: ${htmlFiles.length}`);
  console.log(`   - Files modified: ${totalFilesModified}`);
  console.log(`   - Links fixed: ${totalLinksFixed}`);
  console.log(`   - Replaced with original: ${stats.replacedWithOriginal}`);
  console.log(`   - Original not found: ${stats.originalNotFound}`);

  if (stats.originalNotFound > 0) {
    console.log(`\n⚠️  Warning: ${stats.originalNotFound} thumbnail links could not be fixed`);
    console.log(`   (Original image files not found)`);
  }

  console.log(`\n💡 Next step: node scripts/check-broken-images.js`);
}

fixThumbnailLinks().catch(console.error);
