/**
 * Remove PHP and Rename index.php to index.html
 *
 * 機能:
 * - index.php ファイルから PHP タグを削除
 * - HTML コンテンツのみ残す
 * - ページネーション内のコンテンツはすべて表示（全ページ結合）
 * - index.html として保存
 * - 元の index.php を .php.bak にバックアップ
 *
 * 使用方法:
 *   node scripts/remove-php-and-rename-index.js [--dry-run] [--no-backup]
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
  pattern: '**/index.php',
  ignore: ['node_modules/**', '_site/**', 'vendor/**'],

  // オプション
  dryRun: process.argv.includes('--dry-run'),
  noBackup: process.argv.includes('--no-backup'),
};

// ========== 統計情報 ==========
const stats = {
  scanned: 0,
  converted: 0,
  skipped: 0,
  errors: 0,
};

// ========== ユーティリティ ==========

const colors = {
  red: (text) => `\x1b[31m${text}\x1b[0m`,
  green: (text) => `\x1b[32m${text}\x1b[0m`,
  yellow: (text) => `\x1b[33m${text}\x1b[0m`,
  cyan: (text) => `\x1b[36m${text}\x1b[0m`,
  dim: (text) => `\x1b[2m${text}\x1b[0m`,
  magenta: (text) => `\x1b[35m${text}\x1b[0m`,
};

/**
 * PHPコードを削除してHTMLのみを残す
 */
function removePHP(content) {
  let result = content;
  let removedCount = 0;

  // 1. <?php if (false) : ?> ... <?php endif; ?> ブロックを完全削除（警告メッセージ）
  const falseBlockPattern = /<\?php\s+if\s*\(\s*false\s*\)\s*:\s*\?>([\s\S]*?)<\?php\s+endif;\s*\?>/gi;
  result = result.replace(falseBlockPattern, (match) => {
    removedCount++;
    return '';
  });

  // 2. 大きな PHP ブロック（変数定義、ロジック）を削除
  // <?php から ?> までで、複数行にわたるものを削除
  const phpBlockPattern = /<\?php[\s\S]*?\?>/g;

  // ただし、条件分岐内のコンテンツは保持する必要がある
  // <?php if($paginate_current_page == X || $paginate_current_page == 'all') : ?> と <?php endif; ?> は
  // タグだけ削除してコンテンツは残す

  // 3. 条件分岐の開始タグを削除（コンテンツは残す）
  const ifStartPattern = /<\?php\s+if\s*\([^)]*\$paginate_current_page[^)]*\)\s*:\s*\?>/gi;
  result = result.replace(ifStartPattern, (match) => {
    removedCount++;
    return '';
  });

  // 4. endif タグを削除
  const endifPattern = /<\?php\s+endif;\s*\?>/gi;
  result = result.replace(endifPattern, (match) => {
    removedCount++;
    return '';
  });

  // 5. ページネーション生成用のPHPブロック（forループ等）を削除
  // これは複雑なので、特定パターンにマッチさせる
  const paginateNavPattern = /<p\s+class="pagenate">[\s\S]*?<\/p>/gi;
  result = result.replace(paginateNavPattern, (match) => {
    // PHP を含む場合のみ削除
    if (match.includes('<?php')) {
      removedCount++;
      return '<p class="pagenate"><!-- pagination removed --></p>';
    }
    return match;
  });

  // 6. 残りの PHP ブロックを削除（純粋な PHP コードブロック）
  // 変数定義や条件分岐の開始等
  const remainingPhpPattern = /<\?php[\s\S]*?\?>/g;
  result = result.replace(remainingPhpPattern, (match) => {
    // echo や html 出力を含まない純粋な PHP コードは削除
    removedCount++;
    return '';
  });

  // 7. 連続する空行を整理（3行以上の空行を2行に）
  result = result.replace(/\n{4,}/g, '\n\n\n');

  // 8. PHP の短いタグも念のため削除
  result = result.replace(/<\?=[\s\S]*?\?>/g, '');

  return { result, removedCount };
}

/**
 * 変換前後の差分をサマリー表示
 */
function showSummary(filePath, original, converted, removedCount) {
  console.log(colors.cyan(`\n📄 ${filePath}`));
  console.log(colors.dim('─'.repeat(60)));

  const originalLines = original.split('\n').length;
  const convertedLines = converted.split('\n').length;
  const originalSize = Buffer.byteLength(original, 'utf8');
  const convertedSize = Buffer.byteLength(converted, 'utf8');

  console.log(`   Lines: ${originalLines} → ${convertedLines}`);
  console.log(`   Size:  ${(originalSize / 1024).toFixed(1)}KB → ${(convertedSize / 1024).toFixed(1)}KB`);
  console.log(`   PHP blocks removed: ${removedCount}`);

  // サンプル差分（最初のPHPタグ周辺を表示）
  const phpMatch = original.match(/<\?php/);
  if (phpMatch) {
    const index = phpMatch.index;
    const start = Math.max(0, index - 20);
    const end = Math.min(original.length, index + 80);
    const snippet = original.substring(start, end).replace(/\n/g, '\\n');
    console.log(colors.dim(`   First PHP found at: char ${index}`));
    console.log(colors.red(`   Before: ...${snippet.substring(0, 60)}...`));
  }
}

/**
 * ファイルを処理
 */
async function processFile(filePath) {
  try {
    const dir = path.dirname(filePath);
    const htmlPath = path.join(dir, 'index.html');
    const bakPath = `${filePath}.bak`;

    // すでに index.html が存在する場合
    if (await fs.pathExists(htmlPath)) {
      console.log(colors.yellow(`⏭️  ${filePath} - index.html already exists, skipping`));
      stats.skipped++;
      return { converted: false, reason: 'index.html exists' };
    }

    // ファイル読み込み
    const content = await fs.readFile(filePath, 'utf-8');

    // PHP タグが含まれていない場合
    if (!content.includes('<?php') && !content.includes('<?=')) {
      console.log(colors.yellow(`⏭️  ${filePath} - No PHP found, simple rename`));

      if (!CONFIG.dryRun) {
        // バックアップ
        if (!CONFIG.noBackup) {
          await fs.copy(filePath, bakPath);
        }
        // リネーム
        await fs.move(filePath, htmlPath);
      }
      stats.converted++;
      return { converted: true, noPHP: true };
    }

    // PHP を削除
    const { result, removedCount } = removePHP(content);

    // 変換内容を表示
    showSummary(filePath, content, result, removedCount);

    if (CONFIG.dryRun) {
      console.log(colors.dim('   (dry-run: not saved)'));
      stats.converted++;
      return { converted: true, dryRun: true };
    }

    // バックアップ作成
    if (!CONFIG.noBackup) {
      await fs.copy(filePath, bakPath);
      console.log(colors.dim(`   💾 Backup: ${path.basename(bakPath)}`));
    }

    // index.html として保存
    await fs.writeFile(htmlPath, result, 'utf-8');
    console.log(colors.green(`   ✅ Created: index.html`));

    // 元の index.php を削除（バックアップがあるので）
    if (!CONFIG.noBackup) {
      await fs.remove(filePath);
      console.log(colors.dim(`   🗑️  Removed: index.php`));
    }

    stats.converted++;
    return { converted: true };

  } catch (error) {
    console.error(colors.red(`❌ Error processing ${filePath}: ${error.message}`));
    stats.errors++;
    return { converted: false, error: error.message };
  }
}

/**
 * メイン処理
 */
async function main() {
  console.log('========================================');
  console.log('🔧 Remove PHP and Rename index.php → index.html');
  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('⚠️  DRY RUN MODE - No files will be modified'));
  }
  if (CONFIG.noBackup) {
    console.log(colors.yellow('⚠️  No backup files will be created'));
  }

  console.log(`\n🔍 Searching for: ${CONFIG.pattern}`);

  // index.php ファイルを検索
  const files = await glob(CONFIG.pattern, {
    ignore: CONFIG.ignore,
    nodir: true,
  });

  stats.scanned = files.length;
  console.log(`📊 Found ${files.length} index.php files\n`);

  if (files.length === 0) {
    console.log('No index.php files found.');
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
  console.log(`Files scanned:   ${stats.scanned}`);
  console.log(`Files converted: ${stats.converted}`);
  console.log(`Files skipped:   ${stats.skipped}`);
  console.log(`Errors:          ${stats.errors}`);
  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('\n⚠️  This was a dry run. Run without --dry-run to apply changes.'));
  } else if (stats.converted > 0) {
    console.log(colors.green('\n✅ PHP removal and conversion complete!'));
    if (!CONFIG.noBackup) {
      console.log(colors.dim('   Original files backed up with .php.bak extension'));
    }
    console.log(colors.cyan('\n📌 Next steps:'));
    console.log('   1. Run: npm run serve');
    console.log('   2. Check: http://localhost:8080/2004/');
    console.log('   3. If OK, delete backups: find . -name "*.php.bak" -delete');
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
