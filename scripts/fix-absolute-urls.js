/**
 * Fix Absolute URLs Script
 *
 * 機能:
 * - HTMLファイル内の / を / に置換
 * - / も対応
 * - upload/ → optimized/ への変換オプション
 * - バックアップ作成（.bak）
 * - 変更前後の差分表示
 *
 * 使用方法:
 *   node scripts/fix-absolute-urls.js [--dry-run] [--no-backup] [--fix-upload]
 *
 * オプション:
 *   --dry-run     実際には書き込まず、変更内容のみ表示
 *   --no-backup   バックアップを作成しない
 *   --fix-upload  /upload/ を /optimized/ に変換
 */

const { glob } = require('glob');
const fs = require('fs-extra');
const path = require('path');

// ========== 設定 ==========
const CONFIG = {
  // 対象ファイルパターン
  patterns: [
    '**/*.{html,njk,css,js,xml}',
    '!_site/**',        // ビルド出力は除外
    '!node_modules/**', // node_modulesは除外
    '!*.bak',           // バックアップファイルは除外
  ],

  // 置換パターン（正規表現）
  replacements: [
    {
      // / → /
      pattern: /https?:\/\/(www\.)?as-tetra\.info\//g,
      replacement: '/',
      description: 'Absolute URL → Root relative',
    },
  ],

  // オプション
  dryRun: process.argv.includes('--dry-run'),
  noBackup: process.argv.includes('--no-backup'),
  fixUpload: process.argv.includes('--fix-upload'),
};

// upload/ → optimized/ 変換（オプション）
if (CONFIG.fixUpload) {
  CONFIG.replacements.push({
    pattern: /\/upload\//g,
    replacement: '/optimized/',
    description: '/upload/ → /optimized/',
  });
}

// ========== 統計情報 ==========
const stats = {
  scanned: 0,
  modified: 0,
  skipped: 0,
  errors: 0,
  totalReplacements: 0,
  replacementDetails: {},
};

// ========== ユーティリティ ==========

/**
 * テキストのハイライト表示
 */
const colors = {
  red: (text) => `\x1b[31m${text}\x1b[0m`,
  green: (text) => `\x1b[32m${text}\x1b[0m`,
  yellow: (text) => `\x1b[33m${text}\x1b[0m`,
  cyan: (text) => `\x1b[36m${text}\x1b[0m`,
  dim: (text) => `\x1b[2m${text}\x1b[0m`,
};

/**
 * 差分を表示（変更箇所のみ抜粋）
 */
function showDiff(filePath, original, modified) {
  const originalLines = original.split('\n');
  const modifiedLines = modified.split('\n');

  console.log(colors.cyan(`\n📄 ${filePath}`));
  console.log(colors.dim('─'.repeat(60)));

  let changeCount = 0;
  const maxChangesToShow = 5; // 表示する変更数の上限

  for (let i = 0; i < originalLines.length && changeCount < maxChangesToShow; i++) {
    if (originalLines[i] !== modifiedLines[i]) {
      changeCount++;
      console.log(colors.dim(`Line ${i + 1}:`));
      console.log(colors.red(`  - ${originalLines[i].trim().substring(0, 100)}`));
      console.log(colors.green(`  + ${modifiedLines[i].trim().substring(0, 100)}`));
    }
  }

  if (changeCount >= maxChangesToShow) {
    const remaining = originalLines.filter((line, i) => line !== modifiedLines[i]).length - maxChangesToShow;
    if (remaining > 0) {
      console.log(colors.dim(`  ... and ${remaining} more changes`));
    }
  }
}

/**
 * 置換処理
 */
function applyReplacements(content) {
  let result = content;
  let totalCount = 0;

  for (const { pattern, replacement, description } of CONFIG.replacements) {
    const matches = result.match(pattern);
    if (matches) {
      const count = matches.length;
      totalCount += count;

      // 統計情報を更新
      if (!stats.replacementDetails[description]) {
        stats.replacementDetails[description] = 0;
      }
      stats.replacementDetails[description] += count;
    }
    result = result.replace(pattern, replacement);
  }

  return { result, count: totalCount };
}

/**
 * ファイルを処理
 */
async function processFile(filePath) {
  try {
    // ファイル読み込み
    const content = await fs.readFile(filePath, 'utf-8');

    // 置換処理
    const { result, count } = applyReplacements(content);

    // 変更がない場合はスキップ
    if (content === result) {
      stats.skipped++;
      return { changed: false };
    }

    stats.totalReplacements += count;

    // 差分表示
    showDiff(filePath, content, result);
    console.log(colors.yellow(`  📝 ${count} replacements`));

    // ドライランの場合は書き込まない
    if (CONFIG.dryRun) {
      console.log(colors.dim('  (dry-run: not saved)'));
      stats.modified++;
      return { changed: true, dryRun: true };
    }

    // バックアップ作成
    if (!CONFIG.noBackup) {
      const backupPath = `${filePath}.bak`;
      await fs.copy(filePath, backupPath);
      console.log(colors.dim(`  💾 Backup: ${path.basename(backupPath)}`));
    }

    // ファイル書き込み
    await fs.writeFile(filePath, result, 'utf-8');
    console.log(colors.green('  ✅ Saved'));

    stats.modified++;
    return { changed: true };

  } catch (error) {
    console.error(colors.red(`  ❌ Error: ${error.message}`));
    stats.errors++;
    return { changed: false, error: error.message };
  }
}

/**
 * メイン処理
 */
async function main() {
  console.log('========================================');
  console.log('🔗 Fix Absolute URLs Script');
  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('⚠️  DRY RUN MODE - No files will be modified'));
  }
  if (CONFIG.noBackup) {
    console.log(colors.yellow('⚠️  No backup files will be created'));
  }
  if (CONFIG.fixUpload) {
    console.log(colors.cyan('📁 Also converting /upload/ → /optimized/'));
  }

  console.log('\n📋 Replacement patterns:');
  for (const { description, pattern } of CONFIG.replacements) {
    console.log(`   - ${description}`);
  }

  console.log('\n🔍 Scanning for HTML files...');

  // HTMLファイルを検索
  const files = await glob(CONFIG.patterns[0], {
    ignore: CONFIG.patterns.slice(1).map(p => p.replace('!', '')),
    nodir: true,
  });

  stats.scanned = files.length;
  console.log(`📊 Found ${files.length} HTML files\n`);

  if (files.length === 0) {
    console.log('No HTML files found.');
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
  console.log(`Files scanned:    ${stats.scanned}`);
  console.log(`Files modified:   ${stats.modified}`);
  console.log(`Files skipped:    ${stats.skipped}`);
  console.log(`Errors:           ${stats.errors}`);
  console.log(`Total replacements: ${stats.totalReplacements}`);

  if (Object.keys(stats.replacementDetails).length > 0) {
    console.log('\n📈 Replacement breakdown:');
    for (const [desc, count] of Object.entries(stats.replacementDetails)) {
      console.log(`   ${desc}: ${count}`);
    }
  }

  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('\n⚠️  This was a dry run. Run without --dry-run to apply changes.'));
  } else if (stats.modified > 0) {
    console.log(colors.green('\n✅ URL fixes applied successfully!'));
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
