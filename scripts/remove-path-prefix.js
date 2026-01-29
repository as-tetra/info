/**
 * Remove /info/ prefix from all absolute paths
 * 環境設定で切り替えられるように、ソースファイルをクリーンな状態に戻す
 *
 * 使用方法:
 *   node scripts/remove-path-prefix.js [--dry-run] [--no-backup]
 */

const { glob } = require('glob');
const fs = require('fs-extra');
const path = require('path');

// ========== 設定 ==========
const CONFIG = {
  patterns: [
    '**/*.{html,njk,css,xml}',
    '!_site/**',
    '!node_modules/**',
    '!*.bak',
  ],

  pathPrefix: '/info',

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
 * ファイル内容から /info/ プレフィックスを削除
 */
function removePathPrefix(content) {
  let newContent = content;
  let replacements = 0;

  // href="/info/ と src="/info/ を href="/ と src="/ に置換
  const patterns = [
    { from: /href="\/info\//g, to: 'href="/' },
    { from: /src="\/info\//g, to: 'src="/' },
  ];

  for (const pattern of patterns) {
    const matches = [...content.matchAll(pattern.from)];
    if (matches.length > 0) {
      newContent = newContent.replace(pattern.from, pattern.to);
      replacements += matches.length;
    }
  }

  return { newContent, replacements };
}

/**
 * ファイルを処理
 */
async function processFile(filePath) {
  try {
    stats.scanned++;

    const content = await fs.readFile(filePath, 'utf-8');

    // /info/ が含まれていない場合はスキップ
    if (!content.includes('"/info/')) {
      stats.skipped++;
      return { changed: false };
    }

    // 置換実行
    const { newContent, replacements } = removePathPrefix(content);

    if (replacements === 0) {
      stats.skipped++;
      return { changed: false };
    }

    stats.totalReplacements += replacements;

    // 簡易表示
    console.log(colors.cyan(`📄 ${filePath}`));
    console.log(colors.yellow(`  📝 ${replacements} paths cleaned`));

    if (CONFIG.dryRun) {
      console.log(colors.dim('  (dry-run: not saved)'));
      stats.modified++;
      return { changed: true, dryRun: true };
    }

    // バックアップ作成
    if (!CONFIG.noBackup) {
      const bakPath = `${filePath}.bak`;
      await fs.copy(filePath, bakPath);
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
  console.log('🧹 Remove /info/ Path Prefix');
  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('⚠️  DRY RUN MODE - No files will be modified'));
  }

  console.log('\n🔍 Scanning for files with /info/ prefix...\n');

  const files = await glob(CONFIG.patterns[0], {
    ignore: CONFIG.patterns.slice(1).map(p => p.replace('!', '')),
    nodir: true,
  });

  console.log(`📊 Found ${files.length} files to scan\n`);

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
  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('\n⚠️  This was a dry run. Run without --dry-run to apply changes.'));
  } else if (stats.modified > 0) {
    console.log(colors.green('\n✅ Path prefix removed successfully!'));
    console.log(colors.dim('   Source files are now clean and ready for environment-based builds'));
  }

  if (stats.errors > 0) {
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
