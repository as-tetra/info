/**
 * HTMLファイル内のURL正規化スクリプト
 *
 * 以下を一括処理:
 * 1. 絶対URL → 相対パス (http://www.as-tetra.info/xxx → /xxx)
 * 2. image.php → 実画像パス (image.php/...?image=/upload/xxx → /upload/xxx)
 * 3. -thumb 除去
 * 4. 日本語ファイル名 NFD → NFC 正規化
 *
 * Usage:
 *   node scripts/normalize-html-urls.js          # 実行
 *   node scripts/normalize-html-urls.js --dry-run # 確認のみ
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

const dryRun = process.argv.includes('--dry-run');

async function normalizeUrls() {
  console.log(`\n🔧 HTML URL正規化${dryRun ? '（dry-run）' : ''}を開始...\n`);

  const htmlFiles = glob.sync('**/*.html', {
    ignore: ['_site/**', 'node_modules/**']
  });

  console.log(`📁 対象ファイル: ${htmlFiles.length}件\n`);

  let totalFiles = 0;
  let stats = { absoluteUrl: 0, imagePhp: 0, thumb: 0, nfd: 0 };

  for (const file of htmlFiles) {
    let content = await fs.readFile(file, 'utf-8');
    const original = content;
    let fileStats = { absoluteUrl: 0, imagePhp: 0, thumb: 0, nfd: 0 };

    // -------------------------------------------------------
    // 1. 絶対URL → 相対パス
    // -------------------------------------------------------
    const absMatches = content.match(/http:\/\/www\.as-tetra\.info\//g);
    if (absMatches) {
      fileStats.absoluteUrl = absMatches.length;
      content = content.replace(/http:\/\/www\.as-tetra\.info\//g, '/');
    }

    // https版も対応
    const absMatchesHttps = content.match(/https:\/\/www\.as-tetra\.info\//g);
    if (absMatchesHttps) {
      fileStats.absoluteUrl += absMatchesHttps.length;
      content = content.replace(/https:\/\/www\.as-tetra\.info\//g, '/');
    }

    // -------------------------------------------------------
    // 2. image.php → 実画像パス
    //    パターン: /image.php/XXX.jpg?width=NNN&height=NNN&image=/upload/YYYY/file.ext
    //    → /upload/YYYY/file.ext
    //    先頭の / も含めてマッチし、二重スラッシュを防止
    // -------------------------------------------------------
    const imagePhpPattern = /\/?image\.php\/[^"']*?\?[^"']*?image=([^"'&]+)/g;
    let phpMatch;
    const phpReplacements = [];

    // パターンマッチを先に収集（replace中のexec問題回避）
    const contentCopy = content;
    while ((phpMatch = imagePhpPattern.exec(contentCopy)) !== null) {
      const fullMatch = phpMatch[0];
      let imagePath = phpMatch[1];

      // URLデコード
      try {
        imagePath = decodeURIComponent(imagePath);
      } catch (e) {
        // デコード失敗はそのまま
      }

      // -thumb 除去
      imagePath = imagePath.replace(/-thumb(\.[^.]+)$/, '$1');

      // NFC正規化
      imagePath = imagePath.normalize('NFC');

      // パスが / で始まっていなければ追加
      if (!imagePath.startsWith('/')) {
        imagePath = '/' + imagePath;
      }

      phpReplacements.push({ from: fullMatch, to: imagePath });
      fileStats.imagePhp++;
    }

    for (const { from, to } of phpReplacements) {
      content = content.replace(from, to);
    }

    // 二重スラッシュ修正（//upload → /upload など）
    content = content.replace(/([="'])\/\/(upload|archives|images|css|js|data|genre|tetra|special)\//g, '$1/$2/');

    // -------------------------------------------------------
    // 3. 残存する -thumb を除去（image.php以外にも）
    //    /upload/YYYY/filename-thumb.ext → /upload/YYYY/filename.ext
    // -------------------------------------------------------
    const thumbPattern = /(\/upload\/[^"']*?)-thumb(\.[^."']+)/g;
    const thumbMatches = content.match(thumbPattern);
    if (thumbMatches) {
      fileStats.thumb = thumbMatches.length;
      content = content.replace(thumbPattern, '$1$2');
    }

    // -------------------------------------------------------
    // 4. NFD → NFC 正規化（パーセントエンコードされたURL）
    // -------------------------------------------------------
    const encodedUrlPattern = /((?:src|href)=["'])([^"']*%[0-9A-Fa-f]{2}[^"']*)(["'])/g;
    let nfdMatch;
    const nfdReplacements = [];
    const contentForNfd = content;

    while ((nfdMatch = encodedUrlPattern.exec(contentForNfd)) !== null) {
      const prefix = nfdMatch[1];
      const encodedUrl = nfdMatch[2];
      const suffix = nfdMatch[3];

      try {
        const decoded = decodeURIComponent(encodedUrl);
        const normalized = decoded.normalize('NFC');
        const reencoded = encodeURI(normalized);

        if (encodedUrl !== reencoded) {
          nfdReplacements.push({
            from: prefix + encodedUrl + suffix,
            to: prefix + reencoded + suffix
          });
          fileStats.nfd++;
        }
      } catch (e) {
        // デコードエラーは無視
      }
    }

    for (const { from, to } of nfdReplacements) {
      content = content.replace(from, to);
    }

    // -------------------------------------------------------
    // 書き込み
    // -------------------------------------------------------
    const changed = content !== original;
    if (changed) {
      const parts = [];
      if (fileStats.absoluteUrl > 0) parts.push(`絶対URL: ${fileStats.absoluteUrl}`);
      if (fileStats.imagePhp > 0)    parts.push(`image.php: ${fileStats.imagePhp}`);
      if (fileStats.thumb > 0)       parts.push(`thumb: ${fileStats.thumb}`);
      if (fileStats.nfd > 0)         parts.push(`NFD→NFC: ${fileStats.nfd}`);

      console.log(`✅ ${file} (${parts.join(', ')})`);

      if (!dryRun) {
        await fs.writeFile(file, content, 'utf-8');
      }

      totalFiles++;
      stats.absoluteUrl += fileStats.absoluteUrl;
      stats.imagePhp += fileStats.imagePhp;
      stats.thumb += fileStats.thumb;
      stats.nfd += fileStats.nfd;
    }
  }

  console.log(`\n${ dryRun ? '🔍 dry-run' : '✅' } 完了！`);
  console.log(`📊 サマリー:`);
  console.log(`   修正ファイル数: ${totalFiles}`);
  console.log(`   絶対URL → 相対パス: ${stats.absoluteUrl}箇所`);
  console.log(`   image.php → 実画像パス: ${stats.imagePhp}箇所`);
  console.log(`   -thumb 除去: ${stats.thumb}箇所`);
  console.log(`   NFD → NFC 正規化: ${stats.nfd}箇所`);
  console.log(`   合計: ${stats.absoluteUrl + stats.imagePhp + stats.thumb + stats.nfd}箇所`);
}

normalizeUrls().catch(console.error);
