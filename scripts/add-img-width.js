/**
 * 静的HTMLファイルの .block_box 内 img に width="168" を自動追加
 *
 * 対象:
 *   - PassthroughCopyされる静的HTMLファイル（index.html, top/, cat47/ 等）
 *   - /upload/ パスの img タグで width 属性がないもの
 * 除外: _site/, node_modules/, data/, data_en/, archives/（個別エントリー）
 *
 * Usage:
 *   node scripts/add-img-width.js          # 実行
 *   node scripts/add-img-width.js --dry-run # 確認のみ
 */

const fs = require('fs-extra');
const glob = require('glob');

const dryRun = process.argv.includes('--dry-run');
const DEFAULT_WIDTH = '168';

async function addImgWidth() {
  console.log(`\n🔧 img への width="${DEFAULT_WIDTH}" 追加${dryRun ? '（dry-run）' : ''}を開始...\n`);

  const htmlFiles = glob.sync('**/*.html', {
    ignore: [
      '_site/**',
      'node_modules/**',
      'data/**',
      'data_en/**',
      'archives/**',
      'images/mm_images/**',
    ]
  });

  console.log(`📁 スキャン対象: ${htmlFiles.length}件\n`);

  let totalFiles = 0;
  let totalImgs = 0;

  for (const file of htmlFiles) {
    const original = await fs.readFile(file, 'utf-8');
    let content = original;
    let count = 0;

    // /upload/ パスを持つ img タグ全体にマッチ（width なし）
    // XHTML の <img ... /> と HTML の <img ...> の両方に対応
    // タグ全体をマッチしてから末尾の閉じ部分の直前に width を挿入
    content = content.replace(
      /<img\b(?![^>]*\bwidth=)[^>]*\bsrc="\/upload\/[^"]*"[^>]*>/gi,
      (match) => {
        count++;
        // 末尾の " />" または " >" または "/>" または ">" の直前に width="168" を挿入
        return match.replace(/(\s*\/?>)$/, ` width="${DEFAULT_WIDTH}"$1`);
      }
    );

    if (count > 0) {
      console.log(`✅ ${file} (${count}件)`);
      if (!dryRun) {
        await fs.writeFile(file, content, 'utf-8');
      }
      totalFiles++;
      totalImgs += count;
    }
  }

  console.log(`\n${dryRun ? '🔍 dry-run' : '✅'} 完了！`);
  console.log(`📊 サマリー:`);
  console.log(`   修正ファイル数: ${totalFiles}`);
  console.log(`   追加した width 属性: ${totalImgs}件`);
}

addImgWidth().catch(console.error);
