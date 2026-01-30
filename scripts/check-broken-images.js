/**
 * 画像リンク切れチェックツール
 * 全HTMLファイルから<img>タグを抽出し、画像ファイルの存在を確認
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');
const cheerio = require('cheerio');

async function checkBrokenImages() {
  console.log('\n🔍 Checking for broken image links...\n');

  // 対象HTMLファイルを検索
  const htmlFiles = glob.sync('**/*.html', {
    ignore: [
      'node_modules/**',
      '_site/**',
      'cgi-bin/**',
      'data/**',
      'data_en/**'
    ]
  });

  console.log(`📁 Found ${htmlFiles.length} HTML files\n`);

  const brokenImages = [];
  const missingFiles = new Set();
  const stats = {
    totalHtmlFiles: htmlFiles.length,
    totalImages: 0,
    brokenLinks: 0,
    validLinks: 0
  };

  for (const htmlFile of htmlFiles) {
    const content = await fs.readFile(htmlFile, 'utf-8');
    const $ = cheerio.load(content);

    $('img').each((i, elem) => {
      const src = $(elem).attr('src');
      if (!src) return;

      stats.totalImages++;

      // 外部URLはスキップ
      if (src.startsWith('http://') || src.startsWith('https://') || src.startsWith('//')) {
        stats.validLinks++;
        return;
      }

      // 相対パスを絶対パスに変換
      const htmlDir = path.dirname(htmlFile);
      let imagePath;

      if (src.startsWith('/')) {
        // ルート相対パス
        imagePath = src.substring(1); // 先頭の / を削除
      } else {
        // 相対パス
        imagePath = path.join(htmlDir, src);
      }

      // パスを正規化
      imagePath = path.normalize(imagePath);

      // ファイルの存在を確認
      if (!fs.existsSync(imagePath)) {
        stats.brokenLinks++;
        missingFiles.add(imagePath);

        brokenImages.push({
          htmlFile,
          src,
          resolvedPath: imagePath,
          alt: $(elem).attr('alt') || '(no alt)'
        });
      } else {
        stats.validLinks++;
      }
    });
  }

  // 結果を表示
  console.log('📊 Summary:');
  console.log(`   - HTML files scanned: ${stats.totalHtmlFiles}`);
  console.log(`   - Total <img> tags: ${stats.totalImages}`);
  console.log(`   - Valid links: ${stats.validLinks}`);
  console.log(`   - Broken links: ${stats.brokenLinks}\n`);

  if (brokenImages.length > 0) {
    console.log('❌ Broken image links found:\n');

    // ファイル別にグループ化
    const byFile = {};
    brokenImages.forEach(item => {
      if (!byFile[item.htmlFile]) {
        byFile[item.htmlFile] = [];
      }
      byFile[item.htmlFile].push(item);
    });

    // 最初の20個を表示
    const files = Object.keys(byFile).slice(0, 20);
    files.forEach(file => {
      console.log(`📄 ${file}:`);
      byFile[file].forEach(img => {
        console.log(`   ❌ src="${img.src}"`);
        console.log(`      → Missing: ${img.resolvedPath}`);
      });
      console.log('');
    });

    if (Object.keys(byFile).length > 20) {
      console.log(`   ... and ${Object.keys(byFile).length - 20} more files with broken images\n`);
    }

    // 不足ファイルのパターンを分析
    console.log('📋 Missing file patterns:');
    const patterns = {};
    missingFiles.forEach(file => {
      const dir = path.dirname(file);
      const ext = path.extname(file);
      const key = `${dir}/*${ext}`;
      patterns[key] = (patterns[key] || 0) + 1;
    });

    Object.entries(patterns)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .forEach(([pattern, count]) => {
        console.log(`   - ${pattern}: ${count} files`);
      });

    // レポートファイルを出力
    const reportPath = 'broken-images-report.json';
    await fs.writeFile(reportPath, JSON.stringify({
      stats,
      brokenImages,
      missingFiles: Array.from(missingFiles)
    }, null, 2));
    console.log(`\n📝 Detailed report saved to: ${reportPath}`);
  } else {
    console.log('✅ No broken image links found!');
  }
}

checkBrokenImages().catch(console.error);
