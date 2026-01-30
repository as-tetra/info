/**
 * 最終画像リンク修正
 * - 残りの-thumbリンクを修正（URLエンコード対応）
 * - 末尾スペースの削除
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

async function fixFinalImageLinks() {
  console.log('\n🔧 Final image link fixes...\n');

  const htmlFiles = glob.sync('**/*.html', {
    ignore: ['node_modules/**', '_site/**', 'cgi-bin/**', 'data/**', 'data_en/**']
  });

  console.log(`📁 Found ${htmlFiles.length} HTML files\n`);

  let totalFilesModified = 0;
  let totalLinksFixed = 0;

  for (const file of htmlFiles) {
    let content = await fs.readFile(file, 'utf-8');
    const originalContent = content;

    // 1. URLエンコードされた-thumbファイルを修正
    // src="/upload/2026/art%20apace%20tetra-thumb.png" → src="/upload/2026/art%20apace%20tetra.png"
    const encodedThumbPattern = /(<img[^>]*src=["'])([^"']*?)-thumb(\.[^"'\.]+)(["'][^>]*>)/gi;

    content = content.replace(encodedThumbPattern, (match, prefix, basePath, ext, suffix) => {
      // -thumbを削除
      const originalPath = basePath + ext;

      // URLデコードしてファイル存在チェック
      try {
        const decodedPath = decodeURIComponent(originalPath);
        const normalizedPath = decodedPath.startsWith('/') ? decodedPath.substring(1) : decodedPath;

        if (fs.existsSync(normalizedPath)) {
          totalLinksFixed++;
          return prefix + originalPath + suffix;
        }
      } catch (e) {
        // デコードエラーは無視
      }

      return match;
    });

    // 2. 末尾スペースを削除（src属性内）
    const spacePattern = /(<img[^>]*src=["'])([^"']+?)\s+(["'])/gi;
    content = content.replace(spacePattern, (match, prefix, srcPath, quote) => {
      totalLinksFixed++;
      return prefix + srcPath.trim() + quote;
    });

    // 3. 多重-thumbの再処理（-thumb-thumb-thumb...）
    const multiThumbPattern2 = /(<img[^>]*src=["'])([^"']*?)-thumb-thumb[^"']*(["'][^>]*>)/gi;
    content = content.replace(multiThumbPattern2, (match, prefix, basePath, suffix) => {
      // 最初の拡張子を探す
      const extMatch = basePath.match(/\.[a-zA-Z]{2,4}$/);
      if (!extMatch) return match;

      const ext = extMatch[0];
      const cleanBase = basePath.substring(0, basePath.lastIndexOf(ext));
      const originalPath = cleanBase + ext;

      try {
        const decodedPath = decodeURIComponent(originalPath);
        const normalizedPath = decodedPath.startsWith('/') ? decodedPath.substring(1) : decodedPath;

        if (fs.existsSync(normalizedPath)) {
          totalLinksFixed++;
          return prefix + originalPath + suffix;
        }
      } catch (e) {
        // デコードエラーは無視
      }

      return match;
    });

    // 4. ファイル名の&を含むケースを処理
    // otto&orabu_2 (1)-thumb.jpg のようなケース
    const ampThumbPattern = /(<img[^>]*src=["'])([^"']*&[^"']*)-thumb(\.[^"'\.]+)(["'][^>]*>)/gi;
    content = content.replace(ampThumbPattern, (match, prefix, basePath, ext, suffix) => {
      const originalPath = basePath + ext;
      const normalizedPath = originalPath.startsWith('/') ? originalPath.substring(1) : originalPath;

      // & をそのまま含むファイルとしてチェック
      if (fs.existsSync(normalizedPath)) {
        totalLinksFixed++;
        return prefix + originalPath + suffix;
      }

      return match;
    });

    if (content !== originalContent) {
      await fs.writeFile(file, content, 'utf-8');
      totalFilesModified++;
    }
  }

  console.log(`✅ Complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - Files processed: ${htmlFiles.length}`);
  console.log(`   - Files modified: ${totalFilesModified}`);
  console.log(`   - Links fixed: ${totalLinksFixed}`);
  console.log(`\n💡 Next step: node scripts/check-broken-images.js`);
}

fixFinalImageLinks().catch(console.error);
