/**
 * サムネイル重複ファイルの削除
 * upload/ 配下の *-thumb.* ファイルを削除
 * 元画像と同じサイズのサムネイルが638個存在し、約67MBを占有
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

async function deleteThumbnails() {
  console.log('\n🔍 Finding thumbnail files...\\n');

  // upload/ 配下の全サムネイルファイルを検索
  const thumbFiles = glob.sync('upload/**/*-thumb.*', {
    nodir: true
  });

  console.log(`📁 Found ${thumbFiles.length} thumbnail files\\n`);

  if (thumbFiles.length === 0) {
    console.log('✅ No thumbnails found to delete');
    return;
  }

  // サイズを計算
  let totalSize = 0;
  for (const file of thumbFiles) {
    const stats = await fs.stat(file);
    totalSize += stats.size;
  }

  const totalSizeMB = (totalSize / (1024 * 1024)).toFixed(2);
  console.log(`📊 Total size: ${totalSizeMB} MB\\n`);

  // サンプルを表示
  console.log('📝 Sample files to be deleted:');
  thumbFiles.slice(0, 10).forEach(file => {
    console.log(`   - ${file}`);
  });
  if (thumbFiles.length > 10) {
    console.log(`   ... and ${thumbFiles.length - 10} more files\\n`);
  }

  // 削除実行
  console.log('\\n🗑️  Deleting thumbnails...\\n');

  let deletedCount = 0;
  for (const file of thumbFiles) {
    await fs.remove(file);
    deletedCount++;

    // 進捗を50ファイルごとに表示
    if (deletedCount % 50 === 0) {
      console.log(`   Deleted ${deletedCount}/${thumbFiles.length} files...`);
    }
  }

  console.log(`\\n✅ Complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - Files deleted: ${deletedCount}`);
  console.log(`   - Space freed: ${totalSizeMB} MB`);
  console.log(`\\n💡 Next step: npm run build:local`);
}

deleteThumbnails().catch(console.error);
