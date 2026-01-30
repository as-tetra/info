/**
 * 包括的画像リンク修正ツール
 * 1. upload/の実ファイルをスキャン
 * 2. 全HTML/データファイルの画像参照を確認
 * 3. 破損リンクと実ファイルを照合・修正
 */

const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');

async function comprehensiveImageFix() {
  console.log('\n🔍 Starting comprehensive image fix...\n');

  // 1. 実際のファイル一覧を取得
  console.log('📁 Scanning actual files in upload/...');
  const actualFiles = glob.sync('upload/**/*.{jpg,jpeg,png,gif,JPG,JPEG,PNG,GIF,webp,WEBP}', {
    nodir: true
  });

  console.log(`   Found ${actualFiles.length} actual image files\n`);

  // ファイル名のマップを作成（パスの正規化版とフルパス）
  // NFC正規化を適用して日本語ファイル名の濁点問題を解決
  const fileMap = new Map();
  actualFiles.forEach(file => {
    // NFC正規化（濁点を合成形に統一）
    const basename = path.basename(file).normalize('NFC');
    const normalizedPath = file.replace(/^\//, '').normalize('NFC'); // 先頭の/を削除 + NFC正規化

    // ファイル名だけのマップ
    if (!fileMap.has(basename)) {
      fileMap.set(basename, []);
    }
    fileMap.get(basename).push(normalizedPath);

    // フルパスのマップ
    fileMap.set(normalizedPath, normalizedPath);
  });

  // 2. 全HTML/データファイルをスキャン
  console.log('📄 Scanning all HTML and data files...');
  const htmlFiles = glob.sync('**/*.html', {
    ignore: ['node_modules/**', '_site/**', 'cgi-bin/**']
  });

  const dataFiles = glob.sync('_data/**/*.{js,json}');
  const allFiles = [...htmlFiles, ...dataFiles];

  console.log(`   Found ${allFiles.length} files to check\n`);

  let totalFilesModified = 0;
  let totalLinksFixed = 0;
  const unfixableLinks = [];

  // 3. 各ファイルをチェック・修正
  for (const file of allFiles) {
    let content = await fs.readFile(file, 'utf-8');
    const originalContent = content;

    // 画像参照パターンを抽出
    const imgPattern = /(?:src=["']|imgSrc["']:\s*["'])([^"']*?\.(?:jpg|jpeg|png|gif|JPG|JPEG|PNG|GIF|webp|WEBP))["']/g;

    let match;
    const replacements = [];

    while ((match = imgPattern.exec(content)) !== null) {
      const originalPath = match[1].normalize('NFC'); // NFC正規化
      const normalizedPath = originalPath.replace(/^\//, '').normalize('NFC');

      // ファイルが存在するかチェック
      if (!fs.existsSync(normalizedPath)) {
        // 存在しない場合、修正を試みる
        const basename = path.basename(normalizedPath).normalize('NFC');
        const dirname = path.dirname(normalizedPath);

        let fixedPath = null;

        // 戦略1: 同じファイル名を upload/ 全体から探す
        if (fileMap.has(basename)) {
          const candidates = fileMap.get(basename);
          // 同じディレクトリ階層を優先
          const yearMatch = dirname.match(/upload\/(\d{4})/);
          if (yearMatch) {
            const year = yearMatch[1];
            const sameYearCandidates = candidates.filter(c => c.includes(`upload/${year}/`));
            if (sameYearCandidates.length > 0) {
              fixedPath = ('/' + sameYearCandidates[0]).normalize('NFC');
            }
          }

          // 見つからない場合は最初の候補
          if (!fixedPath && candidates.length > 0) {
            fixedPath = ('/' + candidates[0]).normalize('NFC');
          }
        }

        // 戦略2: -thumb を削除してみる
        if (!fixedPath && basename.includes('-thumb')) {
          const withoutThumb = basename.replace(/-thumb(-thumb)*/, '').normalize('NFC');
          if (fileMap.has(withoutThumb)) {
            const candidates = fileMap.get(withoutThumb);
            fixedPath = ('/' + candidates[0]).normalize('NFC');
          }
        }

        // 戦略3: 拡張子を変更してみる (.JPG vs .jpg)
        if (!fixedPath) {
          const withoutExt = basename.replace(/\.[^.]+$/, '');
          const extensions = ['.jpg', '.jpeg', '.png', '.gif', '.JPG', '.JPEG', '.PNG', '.GIF'];

          for (const ext of extensions) {
            const candidate = (withoutExt + ext).normalize('NFC');
            if (fileMap.has(candidate)) {
              const paths = fileMap.get(candidate);
              fixedPath = ('/' + paths[0]).normalize('NFC');
              break;
            }
          }
        }

        // 修正パスが見つかった場合は置換リストに追加
        if (fixedPath) {
          replacements.push({ from: originalPath, to: fixedPath });
        } else {
          unfixableLinks.push({ file, path: originalPath });
        }
      }
    }

    // 置換を適用
    if (replacements.length > 0) {
      replacements.forEach(({ from, to }) => {
        // エスケープして正規表現で置換
        const escapedFrom = from.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const regex = new RegExp(escapedFrom, 'g');
        content = content.replace(regex, to);
        totalLinksFixed++;
      });

      await fs.writeFile(file, content, 'utf-8');
      totalFilesModified++;

      console.log(`✅ ${file}`);
      console.log(`   Fixed ${replacements.length} image references`);
    }
  }

  console.log(`\n✅ Comprehensive fix complete!`);
  console.log(`📊 Summary:`);
  console.log(`   - Files scanned: ${allFiles.length}`);
  console.log(`   - Files modified: ${totalFilesModified}`);
  console.log(`   - Links fixed: ${totalLinksFixed}`);
  console.log(`   - Unfixable links: ${unfixableLinks.length}`);

  if (unfixableLinks.length > 0) {
    console.log(`\n⚠️  Unfixable links (first 20):`);
    unfixableLinks.slice(0, 20).forEach(({ file, path }) => {
      console.log(`   ${file}: ${path}`);
    });

    // レポートファイルに保存
    const reportPath = 'unfixable-images-report.json';
    await fs.writeFile(reportPath, JSON.stringify(unfixableLinks, null, 2));
    console.log(`\n📝 Full report saved to: ${reportPath}`);
  }

  console.log(`\n💡 Next step: npm run clean && npm run build:local`);
}

comprehensiveImageFix().catch(console.error);
