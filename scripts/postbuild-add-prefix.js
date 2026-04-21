/**
 * Post-build script to add path prefix to built files
 * ビルド後の _site/ ディレクトリ内のすべてのHTMLファイルにパスプレフィックスを追加
 *
 * 使用方法:
 *   PATH_PREFIX=/info node scripts/postbuild-add-prefix.js
 */

const { glob } = require('glob');
const fs = require('fs-extra');
const path = require('path');

// ========== 設定 ==========
const CONFIG = {
  // ビルド出力ディレクトリ
  siteDir: '_site',

  // 環境変数から読み取り
  pathPrefix: process.env.PATH_PREFIX || '',

  // 対象ファイルパターン
  patterns: [
    '**/*.{html,css,xml}',
  ],
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
 * ファイル内容に対して置換を実行
 */
function addPathPrefix(content, prefix) {
  if (!prefix) return { newContent: content, replacements: 0 };

  let newContent = content;
  let replacements = 0;

  // href, src, action, etc. の絶対パス（ http:// や https:// で始まらない）に prefix を追加
  const patterns = [
    // href="..." / href = "..." / href='...'
    {
      from: /href\s*=\s*(["'])(\/(?!\/)[^"']*?)\1/g,
      to: (match, quote, url) => `href=${quote}${prefix}${url}${quote}`
    },
    // src="..." / src = "..." / src='...'
    {
      from: /src\s*=\s*(["'])(\/(?!\/)[^"']*?)\1/g,
      to: (match, quote, url) => `src=${quote}${prefix}${url}${quote}`
    },
    // action="..." (form action)
    {
      from: /action\s*=\s*(["'])(\/(?!\/)[^"']*?)\1/g,
      to: (match, quote, url) => `action=${quote}${prefix}${url}${quote}`
    },
    // url(...) (CSS)
    {
      from: /url\(\s*(\/(?!\/)[^)]*?)\s*\)/g,
      to: `url(${prefix}$1)`
    },
    // JavaScript: cssPath: '/xxx' → cssPath: '/prefix/xxx'
    {
      from: /cssPath:\s*(["'])(\/(css\/[^"']*?))\1/g,
      to: (match, quote, url) => `cssPath: ${quote}${prefix}${url}${quote}`
    },
    // JavaScript: {cssPath: '/xxx'} → {cssPath: '/prefix/xxx'}
    {
      from: /\{cssPath:\s*(["'])(\/(css\/[^"']*?))\1\}/g,
      to: (match, quote, url) => `{cssPath: ${quote}${prefix}${url}${quote}}`
    },
  ];

  for (const pattern of patterns) {
    const beforeCount = (content.match(pattern.from) || []).length;
    // replaceの第2引数が文字列か関数かで分岐不要（replaceは両対応）
    newContent = newContent.replace(pattern.from, pattern.to);
    replacements += beforeCount;
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

    // プレフィックスがすでに含まれている場合はスキップ
    if (content.includes(`"${CONFIG.pathPrefix}/`)) {
      stats.skipped++;
      return { changed: false };
    }

    // 置換実行
    const { newContent, replacements } = addPathPrefix(content, CONFIG.pathPrefix);

    if (replacements === 0) {
      stats.skipped++;
      return { changed: false };
    }

    stats.totalReplacements += replacements;

    // ファイル書き込み
    await fs.writeFile(filePath, newContent, 'utf-8');

    stats.modified++;
    return { changed: true, replacements };

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
  console.log('🔧 Post-Build: Add Path Prefix');
  console.log('========================================');

  if (!CONFIG.pathPrefix) {
    console.log(colors.dim('ℹ️  No PATH_PREFIX set, skipping post-build processing'));
    return;
  }

  console.log(`\n🎯 Path Prefix: ${CONFIG.pathPrefix}`);
  console.log(`📁 Target Directory: ${CONFIG.siteDir}`);
  console.log('🔍 Processing built files...\n');

  // _site ディレクトリが存在するか確認
  if (!await fs.pathExists(CONFIG.siteDir)) {
    console.error(colors.red(`❌ Error: ${CONFIG.siteDir} directory not found`));
    console.error(colors.dim('   Run build first: npm run build'));
    process.exit(1);
  }

  // 対象ファイルを検索
  const files = await glob(CONFIG.patterns[0], {
    cwd: CONFIG.siteDir,
    nodir: true,
  });

  console.log(`📊 Found ${files.length} files to process\n`);

  if (files.length === 0) {
    console.log('No files found.');
    return;
  }

  // 各ファイルを処理
  for (const file of files) {
    const filePath = path.join(CONFIG.siteDir, file);
    const result = await processFile(filePath);

    if (result.changed && result.replacements > 0) {
      // 変更が多いファイルのみ表示（50以上）
      if (result.replacements >= 50) {
        console.log(colors.cyan(`📄 ${file}`));
        console.log(colors.yellow(`  📝 ${result.replacements} paths updated`));
      }
    }
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

  if (stats.modified > 0) {
    console.log(colors.green(`\n✅ Path prefix "${CONFIG.pathPrefix}" added to ${stats.modified} files`));
  } else {
    console.log(colors.dim('\nℹ️  No files needed modification'));
  }

  if (stats.errors > 0) {
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
