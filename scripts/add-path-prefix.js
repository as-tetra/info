/**
 * Add /info/ prefix to all absolute paths for GitHub Pages subdirectory deployment
 *
 * 機能:
 * - /css/, /js/, /upload/, /images/, /imagecache/ などの絶対パスに /info/ プレフィックスを追加
 * - href, src 属性が対象
 * - バックアップ作成（.bak）
 * - 変更前後の差分表示
 *
 * 使用方法:
 *   node scripts/add-path-prefix.js [--dry-run] [--no-backup]
 *
 * オプション:
 *   --dry-run     実際には書き込まず、変更内容のみ表示
 *   --no-backup   バックアップを作成しない
 */

const { glob } = require('glob');
const fs = require('fs-extra');
const path = require('path');

// ========== 設定 ==========
const CONFIG = {
  // 対象ファイルパターン
  patterns: [
    '**/*.{html,njk,css,xml}',
    '!_site/**',
    '!node_modules/**',
    '!*.bak',
  ],

  // プレフィックス
  pathPrefix: '/info',

  // 置換対象のパス（絶対パスのみ）
  pathsToReplace: [
    '/css/',
    '/js/',
    '/upload/',
    '/images/',
    '/imagecache/',
    '/archives/',
    '/genre/',
    '/2004/',
    '/2005/',
    '/2006/',
    '/2007/',
    '/2008/',
    '/2009/',
    '/special/',
    '/sponsor/',
    '/cat47/',
    '/choukoku/',
    '/info/',
    '/mobile/',
    '/omake/',
    '/tetra/',
    '/top/',
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
 * ファイル内容に対して置換を実行
 */
function replaceAbsolutePaths(content) {
  let newContent = content;
  let replacements = 0;
  const changes = [];

  // 各パスパターンに対して置換
  for (const targetPath of CONFIG.pathsToReplace) {
    // すでに /info/ が含まれている場合はスキップ
    if (targetPath.includes(CONFIG.pathPrefix)) {
      continue;
    }

    const newPath = CONFIG.pathPrefix + targetPath;

    // href="..." と src="..." の両方に対応
    const regex = new RegExp(`(href|src)="(${targetPath.replace(/\//g, '\\/')})`, 'g');

    // マッチを検出して置換
    const matches = [...content.matchAll(regex)];
    if (matches.length > 0) {
      newContent = newContent.replace(regex, `$1="${newPath}`);
      replacements += matches.length;

      changes.push({
        from: targetPath,
        to: newPath,
        count: matches.length,
      });
    }
  }

  return { newContent, replacements, changes };
}

/**
 * HTMLファイルを処理
 */
async function processFile(filePath) {
  try {
    stats.scanned++;

    // ファイル読み込み
    const content = await fs.readFile(filePath, 'utf-8');

    // 絶対パスが含まれていない場合はスキップ
    const hasAbsolutePath = CONFIG.pathsToReplace.some(p => content.includes(`"${p}`));
    if (!hasAbsolutePath) {
      stats.skipped++;
      return { changed: false };
    }

    // すでに /info/ プレフィックスがある場合はスキップ
    if (content.includes(`"${CONFIG.pathPrefix}/css/`) ||
        content.includes(`"${CONFIG.pathPrefix}/upload/`)) {
      stats.skipped++;
      return { changed: false };
    }

    // 置換実行
    const { newContent, replacements, changes } = replaceAbsolutePaths(content);

    // 変更がない場合はスキップ
    if (replacements === 0) {
      stats.skipped++;
      return { changed: false };
    }

    stats.totalReplacements += replacements;

    // 差分表示
    console.log(colors.cyan(`\n📄 ${filePath}`));
    console.log(colors.dim('─'.repeat(60)));

    for (const change of changes.slice(0, 10)) { // 最初の10件のみ表示
      console.log(colors.red(`  - "${change.from}"`));
      console.log(colors.green(`  + "${change.to}" (${change.count} occurrences)`));
    }

    if (changes.length > 10) {
      console.log(colors.dim(`  ... and ${changes.length - 10} more path patterns`));
    }

    console.log(colors.yellow(`  📝 ${replacements} paths updated`));

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
  console.log('🔗 Add /info/ Path Prefix');
  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('⚠️  DRY RUN MODE - No files will be modified'));
  }
  if (CONFIG.noBackup) {
    console.log(colors.yellow('⚠️  No backup files will be created'));
  }

  console.log(`\n🎯 Target prefix: ${CONFIG.pathPrefix}`);
  console.log('🔍 Scanning for files with absolute paths...');

  // 対象ファイルを検索
  const files = await glob(CONFIG.patterns[0], {
    ignore: CONFIG.patterns.slice(1).map(p => p.replace('!', '')),
    nodir: true,
  });

  console.log(`📊 Found ${files.length} files\n`);

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

  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('\n⚠️  This was a dry run. Run without --dry-run to apply changes.'));
  } else if (stats.modified > 0) {
    console.log(colors.green('\n✅ Path prefix added successfully!'));
    console.log(colors.dim('   All absolute paths now include /info/ prefix for GitHub Pages'));
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
