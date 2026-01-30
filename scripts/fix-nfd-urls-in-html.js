/**
 * 既存HTML内のNFD形式URLをNFC形式に変換
 *
 * 問題: macOSファイルシステムが内部的にNFDで保存するため、
 * Movable Typeが生成した静的HTMLにはNFD形式でエンコードされた
 * 日本語ファイル名が含まれている
 *
 * 解決: HTML内のパーセントエンコードされたURLをデコード → NFC正規化 → 再エンコード
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

async function fixNFDUrlsInHTML() {
  console.log('\n🔧 NFD → NFC URL変換を開始...\n');

  // archives/ 以下の全HTMLファイルを検索（PassthroughCopyされる個別エントリー）
  const htmlFiles = glob.sync('archives/**/*.html', {
    ignore: ['archives/**/index.html'] // index.htmlはEleventyが生成するので除外
  });

  console.log(`📁 対象ファイル: ${htmlFiles.length}件\n`);

  let totalFilesModified = 0;
  let totalUrlsFixed = 0;

  for (const file of htmlFiles) {
    let content = await fs.readFile(file, 'utf-8');
    const originalContent = content;

    // パーセントエンコードされたURLパターンを検出
    // src="/upload/...%XX%XX....*"
    const encodedUrlPattern = /((?:src|href)=["'])([^"']*%[0-9A-Fa-f]{2}[^"']*)(["'])/g;

    let match;
    const replacements = [];

    while ((match = encodedUrlPattern.exec(originalContent)) !== null) {
      const prefix = match[1];    // src=" または href="
      const encodedUrl = match[2]; // パーセントエンコードされたURL
      const suffix = match[3];     // "

      try {
        // デコード
        const decoded = decodeURIComponent(encodedUrl);

        // NFC正規化
        const normalized = decoded.normalize('NFC');

        // 再エンコード
        const reencoded = encodeURI(normalized);

        // 変更があった場合のみ置換リストに追加
        if (encodedUrl !== reencoded) {
          replacements.push({
            from: prefix + encodedUrl + suffix,
            to: prefix + reencoded + suffix
          });
          totalUrlsFixed++;
        }
      } catch (e) {
        // デコードエラーは無視
        console.warn(`  ⚠️  デコードエラー: ${file} - ${encodedUrl}`);
      }
    }

    // 置換を適用
    if (replacements.length > 0) {
      replacements.forEach(({ from, to }) => {
        content = content.replace(from, to);
      });

      await fs.writeFile(file, content, 'utf-8');
      totalFilesModified++;
      console.log(`✅ ${file} - ${replacements.length}件修正`);
    }
  }

  console.log(`\n✅ 完了！`);
  console.log(`📊 サマリー:`);
  console.log(`   - 対象ファイル: ${htmlFiles.length}`);
  console.log(`   - 修正ファイル: ${totalFilesModified}`);
  console.log(`   - 修正URL: ${totalUrlsFixed}`);
  console.log(`\n💡 次のステップ: npm run build:local`);
}

fixNFDUrlsInHTML().catch(console.error);
