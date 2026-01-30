/**
 * 包括的サムネイル修正ツール
 * 全ての-thumb参照を修正（多重thumb、特殊文字対応）
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

async function fixAllThumbsComprehensive() {
  console.log('\n🔧 Comprehensive -thumb fix...\n');

  // 全HTMLファイルを検索
  const htmlFiles = glob.sync('**/*.html', {
    ignore: ['node_modules/**', '_site/**', 'cgi-bin/**', 'data/**', 'data_en/**']
  });

  console.log(`📁 Found ${htmlFiles.length} HTML files\n`);

  let totalFilesModified = 0;
  let totalLinksFixed = 0;

  for (const file of htmlFiles) {
    let content = await fs.readFile(file, 'utf-8');
    const originalContent = content;

    // 1. 全ての-thumb参照を削除（単一、多重問わず）
    // パターン: src="/upload/.../filename-thumb-thumb-thumb.ext"
    const allThumbPattern = /(<img[^>]*src=["'])([^"']*?)(-thumb)+(\.[^"'\.]+)(["'][^>]*>)/gi;

    content = content.replace(allThumbPattern, (match, prefix, basePath, thumbs, ext, suffix) => {
      // -thumbを全て削除
      const cleanPath = basePath + ext;
      const normalizedPath = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;

      // URLデコードを試みる
      try {
        const decodedPath = decodeURIComponent(normalizedPath);
        if (fs.existsSync(decodedPath)) {
          totalLinksFixed++;
          return prefix + cleanPath + suffix;
        }
      } catch (e) {
        // デコード失敗
      }

      // デコードなしで存在確認
      if (fs.existsSync(normalizedPath)) {
        totalLinksFixed++;
        return prefix + cleanPath + suffix;
      }

      // ファイルが見つからない場合は元のまま
      return match;
    });

    // 2. 特定の既知の問題ファイルをマッピング
    const knownMappings = [
      // marxian系
      { from: /marxian-thumb-thumb-thumb-thumb\.jpeg/g, to: 'marxian.jpg' },
      { from: /marxian-thumb-thumb-thumb\.jpeg/g, to: 'marxian.jpg' },
      { from: /marxian-thumb-thumb\.jpeg/g, to: 'marxian.jpg' },
      { from: /marxian-thumb\.jpeg/g, to: 'marxian.jpg' },

      // matija系
      { from: /matija&amp;noid2-thumb\.jpg/g, to: 'matija&noid2.jpg' },
      { from: /matija&noid2-thumb\.jpg/g, to: 'matija&noid2.jpg' },

      // otto系
      { from: /otto&amp;orabu_2 \(1\)-thumb\.jpg/g, to: 'otto&orabu_2 (1).jpg' },
      { from: /otto&orabu_2 \(1\)-thumb\.jpg/g, to: 'otto&orabu_2 (1).jpg' },
    ];

    knownMappings.forEach(({ from, to }) => {
      const matches = content.match(from);
      if (matches) {
        content = content.replace(from, to);
        totalLinksFixed += matches.length;
      }
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
  console.log(`\n💡 Next step: npm run clean && npm run build:local`);
}

fixAllThumbsComprehensive().catch(console.error);
