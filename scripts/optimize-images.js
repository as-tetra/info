/**
 * Image Optimization Script for Movable Type → Eleventy Migration
 *
 * 機能:
 * - upload/ フォルダ内の画像を最適化
 * - JPEG/PNG/GIF を対象
 * - 最大幅1200px（拡大なし）
 * - JPEG品質75%
 * - ディレクトリ構造を保持
 * - 出力先: optimized/
 *
 * 使用方法:
 *   node scripts/optimize-images.js [--webp]
 *
 * オプション:
 *   --webp  WebP形式も同時に生成
 */

const sharp = require('sharp');
const { glob } = require('glob');
const path = require('path');
const fs = require('fs-extra');

// ========== 設定 ==========
const CONFIG = {
  inputDir: 'upload',           // 入力ディレクトリ
  outputDir: 'optimized',       // 出力ディレクトリ
  maxWidth: 1200,               // 最大幅（px）
  jpegQuality: 75,              // JPEG品質 (0-100)
  pngCompressionLevel: 9,       // PNG圧縮レベル (0-9)
  supportedExtensions: ['.jpg', '.jpeg', '.png', '.gif'],
  generateWebp: process.argv.includes('--webp'),  // --webpオプションでWebP生成
};

// ========== 統計情報 ==========
const stats = {
  total: 0,
  processed: 0,
  skipped: 0,
  errors: 0,
  originalSize: 0,
  optimizedSize: 0,
  webpGenerated: 0,
};

/**
 * ファイルサイズを人間が読みやすい形式に変換
 */
function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * 画像を最適化して保存
 */
async function optimizeImage(inputPath, outputPath) {
  try {
    // 入力ファイルのサイズを取得
    const inputStats = await fs.stat(inputPath);
    stats.originalSize += inputStats.size;

    // 出力ディレクトリを作成
    await fs.ensureDir(path.dirname(outputPath));

    // 画像のメタデータを取得
    const metadata = await sharp(inputPath).metadata();
    const ext = path.extname(inputPath).toLowerCase();

    // sharpインスタンスを作成
    let pipeline = sharp(inputPath);

    // リサイズ（最大幅1200px、拡大なし）
    if (metadata.width && metadata.width > CONFIG.maxWidth) {
      pipeline = pipeline.resize(CONFIG.maxWidth, null, {
        withoutEnlargement: true,
        fit: 'inside',
      });
    }

    // フォーマットに応じた処理
    if (ext === '.jpg' || ext === '.jpeg') {
      pipeline = pipeline.jpeg({ quality: CONFIG.jpegQuality, mozjpeg: true });
    } else if (ext === '.png') {
      pipeline = pipeline.png({ compressionLevel: CONFIG.pngCompressionLevel });
    } else if (ext === '.gif') {
      // GIFはそのままコピー（アニメーションGIF対応のため）
      // sharpはアニメーションGIFの完全サポートが限定的
      await fs.copy(inputPath, outputPath);
      const outputStats = await fs.stat(outputPath);
      stats.optimizedSize += outputStats.size;
      return { success: true, isGif: true };
    }

    // 最適化して保存
    await pipeline.toFile(outputPath);

    // 出力ファイルのサイズを取得
    const outputStats = await fs.stat(outputPath);
    stats.optimizedSize += outputStats.size;

    // WebP生成（オプション）
    if (CONFIG.generateWebp && ext !== '.gif') {
      const webpPath = outputPath.replace(/\.(jpe?g|png)$/i, '.webp');

      let webpPipeline = sharp(inputPath);
      if (metadata.width && metadata.width > CONFIG.maxWidth) {
        webpPipeline = webpPipeline.resize(CONFIG.maxWidth, null, {
          withoutEnlargement: true,
          fit: 'inside',
        });
      }
      await webpPipeline.webp({ quality: CONFIG.jpegQuality }).toFile(webpPath);
      stats.webpGenerated++;
    }

    return {
      success: true,
      originalSize: inputStats.size,
      optimizedSize: outputStats.size
    };

  } catch (error) {
    console.error(`  ❌ Error processing ${inputPath}: ${error.message}`);
    stats.errors++;
    return { success: false, error: error.message };
  }
}

/**
 * メイン処理
 */
async function main() {
  console.log('========================================');
  console.log('🖼️  Image Optimization Script');
  console.log('========================================');
  console.log(`📁 Input:  ${CONFIG.inputDir}/`);
  console.log(`📁 Output: ${CONFIG.outputDir}/`);
  console.log(`📐 Max width: ${CONFIG.maxWidth}px`);
  console.log(`🎨 JPEG quality: ${CONFIG.jpegQuality}%`);
  console.log(`🌐 WebP generation: ${CONFIG.generateWebp ? 'ON' : 'OFF'}`);
  console.log('----------------------------------------');

  // 入力ディレクトリの存在確認
  const inputPath = path.resolve(process.cwd(), CONFIG.inputDir);
  if (!await fs.pathExists(inputPath)) {
    console.error(`❌ Input directory not found: ${inputPath}`);
    process.exit(1);
  }

  // 対象画像を検索
  const pattern = `${CONFIG.inputDir}/**/*.{jpg,jpeg,png,gif,JPG,JPEG,PNG,GIF}`;
  console.log(`🔍 Searching for images: ${pattern}`);

  const files = await glob(pattern, { nodir: true });
  stats.total = files.length;

  if (files.length === 0) {
    console.log('⚠️  No images found.');
    return;
  }

  console.log(`📊 Found ${files.length} images to process.\n`);

  // 各画像を処理
  for (let i = 0; i < files.length; i++) {
    const inputFile = files[i];
    const relativePath = path.relative(CONFIG.inputDir, inputFile);
    const outputFile = path.join(CONFIG.outputDir, relativePath);

    // 進捗表示
    const progress = `[${i + 1}/${files.length}]`;
    process.stdout.write(`${progress} Processing: ${relativePath}... `);

    // 既に処理済みかチェック（出力ファイルが存在し、入力より新しい場合はスキップ）
    if (await fs.pathExists(outputFile)) {
      const inputStat = await fs.stat(inputFile);
      const outputStat = await fs.stat(outputFile);
      if (outputStat.mtime >= inputStat.mtime) {
        console.log('⏭️  Skipped (already optimized)');
        stats.skipped++;
        continue;
      }
    }

    const result = await optimizeImage(inputFile, outputFile);

    if (result.success) {
      stats.processed++;
      if (result.isGif) {
        console.log('✅ Copied (GIF)');
      } else {
        const savings = result.originalSize - result.optimizedSize;
        const savingsPercent = ((savings / result.originalSize) * 100).toFixed(1);
        console.log(`✅ Done (${formatBytes(result.originalSize)} → ${formatBytes(result.optimizedSize)}, -${savingsPercent}%)`);
      }
    }
  }

  // 結果サマリー
  console.log('\n========================================');
  console.log('📊 Summary');
  console.log('========================================');
  console.log(`Total files:     ${stats.total}`);
  console.log(`Processed:       ${stats.processed}`);
  console.log(`Skipped:         ${stats.skipped}`);
  console.log(`Errors:          ${stats.errors}`);
  console.log('----------------------------------------');
  console.log(`Original size:   ${formatBytes(stats.originalSize)}`);
  console.log(`Optimized size:  ${formatBytes(stats.optimizedSize)}`);

  if (stats.originalSize > 0) {
    const totalSavings = stats.originalSize - stats.optimizedSize;
    const savingsPercent = ((totalSavings / stats.originalSize) * 100).toFixed(1);
    console.log(`Savings:         ${formatBytes(totalSavings)} (${savingsPercent}%)`);
  }

  if (CONFIG.generateWebp) {
    console.log(`WebP generated:  ${stats.webpGenerated}`);
  }

  console.log('========================================');

  if (stats.errors > 0) {
    console.log(`\n⚠️  ${stats.errors} errors occurred. Check the logs above.`);
    process.exit(1);
  }

  console.log('\n✅ Image optimization complete!');
}

// 実行
main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
