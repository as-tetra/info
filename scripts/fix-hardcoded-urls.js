/**
 * Fix hardcoded absolute URLs in static HTML files
 * 静的HTMLファイル内のハードコードされた絶対URLを相対パスに修正
 *
 * 使用方法:
 *   node scripts/fix-hardcoded-urls.js [--dry-run] [--no-backup]
 */

const { glob } = require('glob');
const fs = require('fs-extra');
const path = require('path');

// ========== 設定 ==========
const CONFIG = {
  patterns: [
    '**/*.{html,njk,css,js}',
    '!_site/**',
    '!node_modules/**',
    '!*.bak',
  ],

  // 修正対象のドメイン
  domains: [
    'http://www.as-tetra.info',
    'https://www.as-tetra.info',
    'http://as-tetra.info',
    'https://as-tetra.info',
  ],

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

const colors = {
  red: (text) => `\x1b[31m${text}\x1b[0m`,
  green: (text) => `\x1b[32m${text}\x1b[0m`,
  yellow: (text) => `\x1b[33m${text}\x1b[0m`,
  cyan: (text) => `\x1b[36m${text}\x1b[0m`,
  dim: (text) => `\x1b[2m${text}\x1b[0m`,
};

/**
 * ファイル内容を修正
 */
function fixHardcodedUrls(content) {
  let newContent = content;
  let replacements = 0;
  const changes = [];

  for (const domain of CONFIG.domains) {
    // href="/xxx" → href="/xxx"
    const hrefPattern = new RegExp(`href="${domain.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(/[^"]*?)"`, 'g');
    const hrefMatches = [...content.matchAll(hrefPattern)];
    if (hrefMatches.length > 0) {
      newContent = newContent.replace(hrefPattern, 'href="$1"');
      replacements += hrefMatches.length;
      changes.push({ pattern: 'href', domain, count: hrefMatches.length });
    }

    // src="/xxx" → src="/xxx"
    const srcPattern = new RegExp(`src="${domain.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(/[^"]*?)"`, 'g');
    const srcMatches = [...content.matchAll(srcPattern)];
    if (srcMatches.length > 0) {
      newContent = newContent.replace(srcPattern, 'src="$1"');
      replacements += srcMatches.length;
      changes.push({ pattern: 'src', domain, count: srcMatches.length });
    }

    // cssPath: '/css/xxx' → cssPath: '/css/xxx'
    const cssPathPattern = new RegExp(`cssPath:\\s*['"]${domain.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(/css/[^'"]*?)['"]`, 'g');
    const cssPathMatches = [...content.matchAll(cssPathPattern)];
    if (cssPathMatches.length > 0) {
      newContent = newContent.replace(cssPathPattern, "cssPath: '$1'");
      replacements += cssPathMatches.length;
      changes.push({ pattern: 'cssPath', domain, count: cssPathMatches.length });
    }

    // url(/xxx) → url(/xxx)
    const urlPattern = new RegExp(`url\\(${domain.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(/[^)]*?)\\)`, 'g');
    const urlMatches = [...content.matchAll(urlPattern)];
    if (urlMatches.length > 0) {
      newContent = newContent.replace(urlPattern, 'url($1)');
      replacements += urlMatches.length;
      changes.push({ pattern: 'url()', domain, count: urlMatches.length });
    }
  }

  return { newContent, replacements, changes };
}

/**
 * ファイルを処理
 */
async function processFile(filePath) {
  try {
    stats.scanned++;

    const content = await fs.readFile(filePath, 'utf-8');

    // ドメインが含まれていない場合はスキップ
    const hasDomain = CONFIG.domains.some(domain => content.includes(domain));
    if (!hasDomain) {
      stats.skipped++;
      return { changed: false };
    }

    // 修正実行
    const { newContent, replacements, changes } = fixHardcodedUrls(content);

    if (replacements === 0) {
      stats.skipped++;
      return { changed: false };
    }

    stats.totalReplacements += replacements;

    // 差分表示
    console.log(colors.cyan(`\n📄 ${filePath}`));
    console.log(colors.dim('─'.repeat(60)));

    for (const change of changes) {
      console.log(colors.green(`  ✓ ${change.pattern}: ${change.count} occurrences`));
      console.log(colors.dim(`    ${change.domain} → (relative path)`));
    }

    console.log(colors.yellow(`  📝 ${replacements} URLs fixed`));

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
  console.log('🔗 Fix Hardcoded Absolute URLs');
  console.log('========================================');

  if (CONFIG.dryRun) {
    console.log(colors.yellow('⚠️  DRY RUN MODE - No files will be modified'));
  }
  if (CONFIG.noBackup) {
    console.log(colors.yellow('⚠️  No backup files will be created'));
  }

  console.log('\n🎯 Target domains:');
  CONFIG.domains.forEach(domain => console.log(colors.dim(`   - ${domain}`)));

  console.log('\n🔍 Scanning for files with hardcoded URLs...\n');

  const files = await glob(CONFIG.patterns[0], {
    ignore: CONFIG.patterns.slice(1).map(p => p.replace('!', '')),
    nodir: true,
  });

  console.log(`📊 Found ${files.length} files to scan\n`);

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
    console.log(colors.green('\n✅ Hardcoded URLs fixed successfully!'));
    console.log(colors.dim('   All absolute URLs converted to relative paths'));
    if (!CONFIG.noBackup) {
      console.log(colors.dim('   Original files backed up with .bak extension'));
    }
  }

  if (stats.errors > 0) {
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
