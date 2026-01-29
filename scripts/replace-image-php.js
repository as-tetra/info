/**
 * Replace image.php URLs with static paths
 *
 * 機能:
 * - /image.php/xxx.jpg?...&image=/upload/... を /optimized/... に置換
 * - width/height クエリパラメータを img 属性に移動
 * - バックアップ作成（.bak）
 * - 変更前後の差分表示
 *
 * 使用方法:
 *   node scripts/replace-image-php.js [--dry-run] [--no-backup]
 *
 * オプション:
 *   --dry-run     実際には書き込まず、変更内容のみ表示
 *   --no-backup   バックアップを作成しない
 */

const { glob } = require('glob');
const fs = require('fs-extra');
const path = require('path');
const cheerio = require('cheerio');

// ========== 設定 ==========
const CONFIG = {
  // 対象ファイルパターン
  patterns: [
    '**/*.{html,njk}',
    '!_site/**',
    '!node_modules/**',
    '!*.bak',
  ],

  // オプション
  dryRun: process.argv.includes('--dry-run'),
  noBackup: process.argv.includes('--no-backup'),
};

// ========== 統計情報 ==========
const stats = {
  scanned: 0,
  modified: 0,
  skipped: 0,
  errors: 0,
  totalReplacements: 0,
  missingImages: [],
};

// ========== ユーティリティ ==========

const colors = {
  red: (text) => `\x1b[31m${text}\x1b[0m`,
  green: (text) => `\x1b[32m${text}\x1b[0m`,
  yellow: (text) => `\x1b[33m${text}\x1b[0m`,
  cyan: (text) => `\x1b[36m${text}\x1b[0m`,
  dim: (text) => `\x1b[2m${text}\x1b[0m`,
};

/**
 * URLパラメータを解析
 */
function parseImagePhpUrl(url) {
  try {
    // パターン: /image.php/xxx.jpg?width=168&height=800&image=/upload/2026/file-thumb.jpg
    const match = url.match(/\/image\.php\/[^?]+\?(.+)/);
    if (!match) return null;

    const params = new URLSearchParams(match[1]);
    const imagePath = params.get('image');
    const width = params.get('width');
    const height = params.get('height');

    if (!imagePath) return null;

    // パスを正規化（/upload/ のまま使用）
    const optimizedPath = imagePath.replace(/^\/?(upload)\//i, '/upload/');

    return {
      originalUrl: url,
      imagePath: optimizedPath,
      width: width ? parseInt(width) : null,
      height: height ? parseInt(height) : null,
    };
  } catch (error) {
    return null;
  }
}

/**
 * HTMLファイルを処理
 */
async function processFile(filePath) {
  try {
    stats.scanned++;

    // ファイル読み込み
    const content = await fs.readFile(filePath, 'utf-8');

    // image.php が含まれていない場合はスキップ
    if (!content.includes('/image.php/')) {
      stats.skipped++;
      return { changed: false };
    }

    // cheerioでHTMLをパース
    const $ = cheerio.load(content, { decodeEntities: false });
    let replacements = 0;
    const changes = [];

    // img タグで image.php を使用しているものを検索
    $('img[src*="/image.php/"]').each((i, elem) => {
      const $img = $(elem);
      const originalSrc = $img.attr('src');

      const parsed = parseImagePhpUrl(originalSrc);
      if (!parsed) return;

      // 新しいパスを設定
      $img.attr('src', parsed.imagePath);

      // widthのみを設定（heightはブラウザが自動計算してアスペクト比を保つ）
      if (parsed.width && !$img.attr('width')) {
        $img.attr('width', parsed.width);
      }
      // heightは設定しない（アスペクト比を保つため）

      replacements++;
      changes.push({
        from: originalSrc,
        to: parsed.imagePath,
        width: parsed.width,
        height: parsed.height,
      });

      // ファイルが存在するかチェック
      const fullPath = path.join(process.cwd(), parsed.imagePath);
      if (!fs.existsSync(fullPath)) {
        stats.missingImages.push({
          file: filePath,
          path: parsed.imagePath,
        });
      }
    });

    // 変更がない場合はスキップ
    if (replacements === 0) {
      stats.skipped++;
      return { changed: false };
    }

    stats.totalReplacements += replacements;

    // 結果HTMLを取得
    const newContent = $.html();

    // 差分表示
    console.log(colors.cyan(`\n📄 ${filePath}`));
    console.log(colors.dim('─'.repeat(60)));

    for (const change of changes.slice(0, 5)) { // 最初の5件のみ表示
      console.log(colors.red(`  - src="${change.from}"`));
      console.log(colors.green(`  + src="${change.to}" width="${change.width}"`));
    }

    if (changes.length > 5) {
      console.log(colors.dim(`  ... and ${changes.length - 5} more changes`));
    }

    console.log(colors.yellow(`  📝 ${replacements} image.php URLs replaced`));

    if (CONFIG.dryRun) {
      console.log(colors.dim('  (dry-run: not saved)'));
      stats.modified++;
      return { changed: true, dryRun: true };
    }

    // バックアップ作成
    if (!CONFIG.noBackup) {
      const bakPath = `${filePath}.bak`;
      await fs.copy(filePath, bakPath);
      console.log(colors.dim(`  💾 Backup: ${path.basename(bakPath)}`));
    }

    // ファイル書き込み
    await fs.writeFile(filePath, newContent, 'utf-8');
    console.log(colors.green('  ✅ Saved'));

    stats.modified++;
    return { changed: true };

  } catch (error) {
    console.error(colors.red(`❌ Error processing ${filePath}: ${error.message}`));
    stats.errors++;
    return { changed: false, error: error.message };
  }
}

/**
 * メイン処理
 */
async function main() {
  console.log('========================================');
  console.log('🖼️  Replace image.php URLs');
  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('⚠️  DRY RUN MODE - No files will be modified'));
  }
  if (CONFIG.noBackup) {
    console.log(colors.yellow('⚠️  No backup files will be created'));
  }

  console.log('\n🔍 Scanning for files with image.php...');

  // 対象ファイルを検索
  const files = await glob(CONFIG.patterns[0], {
    ignore: CONFIG.patterns.slice(1).map(p => p.replace('!', '')),
    nodir: true,
  });

  console.log(`📊 Found ${files.length} HTML/Nunjucks files\n`);

  if (files.length === 0) {
    console.log('No files found.');
    return;
  }

  // 各ファイルを処理
  for (const file of files) {
    await processFile(file);
  }

  // 結果サマリー
  console.log('\n========================================');
  console.log('📊 Summary');
  console.log('========================================');
  console.log(`Files scanned:        ${stats.scanned}`);
  console.log(`Files modified:       ${stats.modified}`);
  console.log(`Files skipped:        ${stats.skipped}`);
  console.log(`Errors:               ${stats.errors}`);
  console.log(`Total replacements:   ${stats.totalReplacements}`);

  if (stats.missingImages.length > 0) {
    console.log('\n⚠️  Missing image files:');
    const uniqueMissing = [...new Set(stats.missingImages.map(m => m.path))];
    uniqueMissing.slice(0, 10).forEach(img => {
      console.log(colors.yellow(`   - ${img}`));
    });
    if (uniqueMissing.length > 10) {
      console.log(colors.dim(`   ... and ${uniqueMissing.length - 10} more`));
    }
    console.log(colors.dim('\n   💡 Tip: Run image optimization script with smaller sizes'));
  }

  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('\n⚠️  This was a dry run. Run without --dry-run to apply changes.'));
  } else if (stats.modified > 0) {
    console.log(colors.green('\n✅ image.php URLs replaced successfully!'));
    if (!CONFIG.noBackup) {
      console.log(colors.dim('   Original files backed up with .bak extension'));
    }
  }

  if (stats.errors > 0) {
    process.exit(1);
  }
}

// 実行
main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
