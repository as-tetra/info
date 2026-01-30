/**
 * データファイルの-thumb参照を修正
 * _data/archiveEntries.json内の全-thumb参照を削除
 */

const fs = require('fs-extra');

async function fixDataThumbs() {
  console.log('\n🔧 Fixing -thumb references in data files...\n');

  const dataFile = '_data/archiveEntries.json';

  // JSONファイルを読み込み
  const content = await fs.readFile(dataFile, 'utf-8');
  console.log(`📁 Reading ${dataFile}...`);

  // -thumb 参照をカウント
  const thumbMatches = content.match(/-thumb\./g);
  console.log(`🔍 Found ${thumbMatches ? thumbMatches.length : 0} -thumb references\n`);

  if (!thumbMatches || thumbMatches.length === 0) {
    console.log('✅ No -thumb references found!');
    return;
  }

  // 全ての-thumb参照を削除
  // パターン: -thumb.jpeg, -thumb.jpg, -thumb.png, -thumb.JPG, -thumb.gif, etc.
  // また、多重thumbも削除: -thumb-thumb.jpeg
  let fixedContent = content;

  // 多重thumbを先に処理
  fixedContent = fixedContent.replace(/-thumb-thumb-thumb-thumb/g, '');
  fixedContent = fixedContent.replace(/-thumb-thumb-thumb/g, '');
  fixedContent = fixedContent.replace(/-thumb-thumb/g, '');

  // 単一thumbを処理
  fixedContent = fixedContent.replace(/-thumb\./g, '.');

  // 変更をカウント
  const afterMatches = fixedContent.match(/-thumb\./g);
  const fixed = thumbMatches.length - (afterMatches ? afterMatches.length : 0);

  console.log(`✅ Fixed ${fixed} -thumb references\n`);

  // バックアップを作成
  const backupFile = dataFile + '.backup';
  await fs.copy(dataFile, backupFile);
  console.log(`💾 Backup saved to ${backupFile}\n`);

  // 修正版を保存
  await fs.writeFile(dataFile, fixedContent, 'utf-8');
  console.log(`✅ Updated ${dataFile}\n`);

  // JSONとして正しいか検証
  try {
    JSON.parse(fixedContent);
    console.log('✅ JSON validation passed\n');
  } catch (e) {
    console.error('❌ JSON validation failed:', e.message);
    console.error('⚠️  Restoring from backup...');
    await fs.copy(backupFile, dataFile, { overwrite: true });
    throw e;
  }

  console.log('📊 Summary:');
  console.log(`   - -thumb references removed: ${fixed}`);
  console.log(`   - Remaining -thumb references: ${afterMatches ? afterMatches.length : 0}`);

  if (afterMatches && afterMatches.length > 0) {
    console.log(`\n⚠️  Warning: ${afterMatches.length} -thumb references still remain`);
    console.log('   (These may require manual review)');
  }

  console.log(`\n💡 Next step: npm run clean && npm run build:local`);
}

fixDataThumbs().catch(console.error);
