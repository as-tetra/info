/**
 * 大容量画像の最適化
 * - 大きなGIFをWebPに変換
 * - 大きなPNGを最適化
 * - 500KB以上のJPEGを再圧縮
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');
const sharp = require('sharp');

async function optimizeLargeImages() {
  console.log('\n🎨 Optimizing large images...\n');

  const stats = {
    totalFiles: 0,
    optimized: 0,
    gifToWebP: 0,
    pngOptimized: 0,
    jpegOptimized: 0,
    sizeBefore: 0,
    sizeAfter: 0,
    skipped: 0
  };

  // 全画像ファイルを検索
  const imageFiles = glob.sync('upload/**/*.{jpg,jpeg,png,gif,JPG,JPEG,PNG,GIF}', {
    nodir: true
  });

  console.log(`📁 Found ${imageFiles.length} image files\n`);

  const largeFiles = [];
  for (const file of imageFiles) {
    const fileStats = await fs.stat(file);
    if (fileStats.size > 500 * 1024) { // 500KB以上
      largeFiles.push({ file, size: fileStats.size });
    }
  }

  console.log(`🔍 Found ${largeFiles.length} files > 500KB\n`);
  largeFiles.sort((a, b) => b.size - a.size);

  // 上位10個を表示
  console.log('📊 Largest files:');
  largeFiles.slice(0, 10).forEach(({ file, size }) => {
    console.log(`   ${(size / (1024 * 1024)).toFixed(2)} MB - ${file}`);
  });
  console.log('');

  for (const { file, size } of largeFiles) {
    stats.totalFiles++;
    stats.sizeBefore += size;

    const ext = path.extname(file).toLowerCase();
    const dir = path.dirname(file);
    const baseName = path.basename(file, ext);

    try {
      // 1. GIFをWebPに変換 (アニメーション対応)
      if (ext === '.gif') {
        const webpPath = path.join(dir, baseName + '.webp');

        console.log(`🔄 Converting GIF to WebP: ${file}`);
        console.log(`   Original: ${(size / (1024 * 1024)).toFixed(2)} MB`);

        try {
          await sharp(file, { animated: true })
            .webp({ quality: 80, effort: 6 })
            .toFile(webpPath);

          const webpStats = await fs.stat(webpPath);
          const reduction = ((size - webpStats.size) / size * 100).toFixed(1);

          console.log(`   WebP: ${(webpStats.size / (1024 * 1024)).toFixed(2)} MB`);
          console.log(`   ✅ Saved ${reduction}%\n`);

          stats.sizeAfter += webpStats.size;
          stats.gifToWebP++;
          stats.optimized++;

          // 元のGIFは削除しない（HTMLリンクの更新が必要なため）
          console.log(`   ⚠️  Manual action needed: Update HTML links from .gif to .webp\n`);
        } catch (e) {
          console.log(`   ❌ Failed to convert (may not be animated): ${e.message}`);
          // 通常のGIFとして処理
          await sharp(file)
            .webp({ quality: 80 })
            .toFile(webpPath);

          const webpStats = await fs.stat(webpPath);
          stats.sizeAfter += webpStats.size;
          stats.gifToWebP++;
          stats.optimized++;
        }
        continue;
      }

      // 2. PNG最適化
      if (ext === '.png') {
        const optimizedPath = file + '.optimized.png';

        console.log(`🔧 Optimizing PNG: ${file}`);
        console.log(`   Original: ${(size / (1024 * 1024)).toFixed(2)} MB`);

        await sharp(file)
          .png({ quality: 85, compressionLevel: 9 })
          .resize({ width: 2000, withoutEnlargement: true })
          .toFile(optimizedPath);

        const optimizedStats = await fs.stat(optimizedPath);

        // サイズが削減された場合のみ置き換え
        if (optimizedStats.size < size) {
          await fs.move(optimizedPath, file, { overwrite: true });
          const reduction = ((size - optimizedStats.size) / size * 100).toFixed(1);

          console.log(`   Optimized: ${(optimizedStats.size / (1024 * 1024)).toFixed(2)} MB`);
          console.log(`   ✅ Saved ${reduction}%\n`);

          stats.sizeAfter += optimizedStats.size;
          stats.pngOptimized++;
          stats.optimized++;
        } else {
          await fs.remove(optimizedPath);
          console.log(`   ℹ️  Already optimized, no change\n`);
          stats.sizeAfter += size;
          stats.skipped++;
        }
        continue;
      }

      // 3. JPEG/JPG最適化
      if (ext === '.jpg' || ext === '.jpeg') {
        const optimizedPath = file + '.optimized.jpg';

        console.log(`🔧 Optimizing JPEG: ${file}`);
        console.log(`   Original: ${(size / (1024 * 1024)).toFixed(2)} MB`);

        await sharp(file)
          .jpeg({ quality: 82, mozjpeg: true })
          .resize({ width: 2000, withoutEnlargement: true })
          .toFile(optimizedPath);

        const optimizedStats = await fs.stat(optimizedPath);

        // サイズが削減された場合のみ置き換え
        if (optimizedStats.size < size) {
          await fs.move(optimizedPath, file, { overwrite: true });
          const reduction = ((size - optimizedStats.size) / size * 100).toFixed(1);

          console.log(`   Optimized: ${(optimizedStats.size / (1024 * 1024)).toFixed(2)} MB`);
          console.log(`   ✅ Saved ${reduction}%\n`);

          stats.sizeAfter += optimizedStats.size;
          stats.jpegOptimized++;
          stats.optimized++;
        } else {
          await fs.remove(optimizedPath);
          console.log(`   ℹ️  Already optimized, no change\n`);
          stats.sizeAfter += size;
          stats.skipped++;
        }
        continue;
      }

    } catch (error) {
      console.error(`   ❌ Error processing ${file}: ${error.message}\n`);
      stats.sizeAfter += size;
      stats.skipped++;
    }
  }

  const totalSaved = stats.sizeBefore - stats.sizeAfter;
  const savingsPercent = ((totalSaved / stats.sizeBefore) * 100).toFixed(1);

  console.log('\n✅ Optimization complete!');
  console.log(`📊 Summary:`);
  console.log(`   - Total files processed: ${stats.totalFiles}`);
  console.log(`   - Files optimized: ${stats.optimized}`);
  console.log(`   - GIF → WebP: ${stats.gifToWebP}`);
  console.log(`   - PNG optimized: ${stats.pngOptimized}`);
  console.log(`   - JPEG optimized: ${stats.jpegOptimized}`);
  console.log(`   - Skipped (already optimal): ${stats.skipped}`);
  console.log(`\n💾 Storage savings:`);
  console.log(`   - Before: ${(stats.sizeBefore / (1024 * 1024)).toFixed(2)} MB`);
  console.log(`   - After: ${(stats.sizeAfter / (1024 * 1024)).toFixed(2)} MB`);
  console.log(`   - Saved: ${(totalSaved / (1024 * 1024)).toFixed(2)} MB (${savingsPercent}%)`);
}

optimizeLargeImages().catch(console.error);
