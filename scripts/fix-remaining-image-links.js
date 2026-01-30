/**
 * 残りの画像リンク問題を修正
 * - 多重サムネイル (-thumb-thumb など)
 * - URLエンコードされたファイル名
 * - HTML実体参照 (&amp; など)
 * - 末尾スペース
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

async function fixRemainingImageLinks() {
  console.log('\n🔧 Fixing remaining image link issues...\n');

  const htmlFiles = glob.sync('**/*.html', {
    ignore: ['node_modules/**', '_site/**', 'cgi-bin/**', 'data/**', 'data_en/**']
  });

  console.log(`📁 Found ${htmlFiles.length} HTML files\n`);

  let totalFilesModified = 0;
  let totalLinksFixed = 0;
  const fixes = {
    multiThumb: 0,
    urlDecoded: 0,
    htmlEntity: 0,
    trailingSpace: 0,
    notFound: 0
  };

  for (const file of htmlFiles) {
    let content = await fs.readFile(file, 'utf-8');
    const originalContent = content;
    let fileModified = false;

    // 1. 多重サムネイル修正: -thumb-thumb... → 元のファイル
    const multiThumbPattern = /(<img[^>]*src=["'])([^"']*?)(-thumb)+(\.[^"'\.]+)(["'][^>]*>)/gi;
    content = content.replace(multiThumbPattern, (match, prefix, basePath, thumbs, ext, suffix) => {
      // -thumb を全て削除して元のファイル名を取得
      const originalPath = basePath + ext;
      const normalizedPath = originalPath.startsWith('/') ? originalPath.substring(1) : originalPath;

      if (fs.existsSync(normalizedPath)) {
        fixes.multiThumb++;
        return prefix + originalPath + suffix;
      }
      return match;
    });

    // 2. URLエンコードされたファイル名を修正
    // src="/upload/2011/file%281%29.jpg" → src="/upload/2011/file(1).jpg"
    const urlEncodedPattern = /(<img[^>]*src=["'])([^"']*)(["'][^>]*>)/gi;
    content = content.replace(urlEncodedPattern, (match, prefix, srcPath, suffix) => {
      if (srcPath.includes('%')) {
        try {
          const decodedPath = decodeURIComponent(srcPath);
          const normalizedPath = decodedPath.startsWith('/') ? decodedPath.substring(1) : decodedPath;

          // デコードしたパスでファイルが存在するか確認
          if (fs.existsSync(normalizedPath) && decodedPath !== srcPath) {
            fixes.urlDecoded++;
            return prefix + decodedPath + suffix;
          }
        } catch (e) {
          // デコード失敗は無視
        }
      }
      return match;
    });

    // 3. HTML実体参照を修正: &amp; → &
    const htmlEntityPattern = /(<img[^>]*src=["'])([^"']*&amp;[^"']*)(["'][^>]*>)/gi;
    content = content.replace(htmlEntityPattern, (match, prefix, srcPath, suffix) => {
      const unescapedPath = srcPath.replace(/&amp;/g, '&');
      const normalizedPath = unescapedPath.startsWith('/') ? unescapedPath.substring(1) : unescapedPath;

      if (fs.existsSync(normalizedPath) && unescapedPath !== srcPath) {
        fixes.htmlEntity++;
        return prefix + unescapedPath + suffix;
      }
      return match;
    });

    // 4. 末尾スペースを削除
    const trailingSpacePattern = /(<img[^>]*src=["'])([^"']+)\s+(["'][^>]*>)/gi;
    content = content.replace(trailingSpacePattern, (match, prefix, srcPath, suffix) => {
      const trimmedPath = srcPath.trim();
      if (trimmedPath !== srcPath) {
        const normalizedPath = trimmedPath.startsWith('/') ? trimmedPath.substring(1) : trimmedPath;
        if (fs.existsSync(normalizedPath)) {
          fixes.trailingSpace++;
          return prefix + trimmedPath + suffix;
        }
      }
      return match;
    });

    if (content !== originalContent) {
      await fs.writeFile(file, content, 'utf-8');
      totalFilesModified++;
      fileModified = true;
    }
  }

  totalLinksFixed = fixes.multiThumb + fixes.urlDecoded + fixes.htmlEntity + fixes.trailingSpace;

  console.log(`✅ Complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - Files processed: ${htmlFiles.length}`);
  console.log(`   - Files modified: ${totalFilesModified}`);
  console.log(`   - Total links fixed: ${totalLinksFixed}`);
  console.log(`\n   Fix breakdown:`);
  console.log(`   - Multi-thumb removed: ${fixes.multiThumb}`);
  console.log(`   - URL decoded: ${fixes.urlDecoded}`);
  console.log(`   - HTML entities fixed: ${fixes.htmlEntity}`);
  console.log(`   - Trailing spaces removed: ${fixes.trailingSpace}`);

  console.log(`\n💡 Next step: node scripts/check-broken-images.js`);
}

fixRemainingImageLinks().catch(console.error);
