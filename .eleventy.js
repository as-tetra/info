/**
 * Eleventy Configuration
 * Movable Type → Eleventy Static Site Migration
 *
 * 出力: _site/
 * テンプレート: Nunjucks
 */

const fs = require('fs');
const path = require('path');

module.exports = function (eleventyConfig) {

  // ========================================
  // 環境設定
  // ========================================

  // PATH_PREFIX 環境変数から読み取り
  // 例: PATH_PREFIX="/info" npm run build
  // ローカル開発: PATH_PREFIX="" npm run serve (デフォルト)
  // GitHub Pages: PATH_PREFIX="/info" npm run build:ghpages
  const pathPrefix = process.env.PATH_PREFIX || '';

  // ========================================
  // Passthrough Copy - 静的ファイルをそのままコピー
  // ========================================

  // 最適化済み画像
  eleventyConfig.addPassthroughCopy('upload');
  eleventyConfig.addPassthroughCopy("data");
  eleventyConfig.addPassthroughCopy('css');
  eleventyConfig.addPassthroughCopy('js');
  eleventyConfig.addPassthroughCopy('images');
  eleventyConfig.addPassthroughCopy('imagecache');

  // 年別アーカイブ（2004〜2009）
  eleventyConfig.addPassthroughCopy('2004');
  eleventyConfig.addPassthroughCopy('2005');
  eleventyConfig.addPassthroughCopy('2006');
  eleventyConfig.addPassthroughCopy('2007');
  eleventyConfig.addPassthroughCopy('2008');
  eleventyConfig.addPassthroughCopy('2009');

  // アーカイブ・カテゴリページ
  eleventyConfig.addPassthroughCopy('archives');
  eleventyConfig.addPassthroughCopy('genre');

  // その他の静的コンテンツ
  eleventyConfig.addPassthroughCopy('special');
  eleventyConfig.addPassthroughCopy('sponsor');
  eleventyConfig.addPassthroughCopy('cat47');
  eleventyConfig.addPassthroughCopy('choukoku');
  eleventyConfig.addPassthroughCopy('info');
  eleventyConfig.addPassthroughCopy('mobile');
  eleventyConfig.addPassthroughCopy('omake');
  eleventyConfig.addPassthroughCopy('tetra');
  eleventyConfig.addPassthroughCopy('top');

  // ルートレベルの静的ファイル
  eleventyConfig.addPassthroughCopy('*.html');
  eleventyConfig.addPassthroughCopy('*.xml');
  eleventyConfig.addPassthroughCopy('*.css');
  eleventyConfig.addPassthroughCopy('sitemap.xml');
  eleventyConfig.addPassthroughCopy('atom.xml');
  eleventyConfig.addPassthroughCopy('rsd.xml');
  eleventyConfig.addPassthroughCopy('mt-site.js');

  // Google/Yahoo検証ファイル
  eleventyConfig.addPassthroughCopy('googlef1194ab5597e9418.html');
  eleventyConfig.addPassthroughCopy('googlehostedservice.html');
  eleventyConfig.addPassthroughCopy('y_key_*.html');

  // ========================================
  // .nojekyll 自動生成（GitHub Pages用）
  // ========================================
  eleventyConfig.on('eleventy.after', async () => {
    const nojekyllPath = path.join(__dirname, '_site', '.nojekyll');
    fs.writeFileSync(nojekyllPath, '');
    console.log('✅ Created .nojekyll for GitHub Pages');
  });

  // ========================================
  // テンプレート設定
  // ========================================

  // Nunjucksをデフォルトに
  eleventyConfig.setTemplateFormats(['njk', 'html', 'md', 'liquid']);

  // HTMLファイルもテンプレートとして処理可能に
  eleventyConfig.addTemplateFormats('html');

  // ========================================
  // フィルター（必要に応じて追加）
  // ========================================

  // 日付フォーマット
  eleventyConfig.addFilter('dateFormat', (date, format) => {
    if (!date) return '';
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  });

  // 画像パス正規化
  eleventyConfig.addFilter('optimizedImage', (imagePath) => {
    if (!imagePath) return '';
    // すでに /upload/ なのでそのまま返す
    return imagePath;
  });

  // 配列の最大値
  eleventyConfig.addFilter('max', (arr) => {
    if (!Array.isArray(arr)) return arr;
    return Math.max(...arr);
  });

  // 配列の最小値
  eleventyConfig.addFilter('min', (arr) => {
    if (!Array.isArray(arr)) return arr;
    return Math.min(...arr);
  });

  // 年でフィルタリング
  eleventyConfig.addFilter('filterByYear', (entries, year) => {
    if (!entries || !year) return entries;
    return entries.filter(entry => entry.year === year);
  });

  // 配列の長さ
  eleventyConfig.addFilter('length', (arr) => {
    if (!arr) return 0;
    return arr.length;
  });

  // ========================================
  // ショートコード（必要に応じて追加）
  // ========================================

  // 最適化画像用ショートコード（pathPrefix対応）
  eleventyConfig.addShortcode('image', (src, alt, className) => {
    const imagePath = src.replace(/^\/?(upload)\//i, '/upload/');
    const optimizedSrc = pathPrefix ? `${pathPrefix}${imagePath}` : imagePath;
    const classAttr = className ? ` class="${className}"` : '';
    return `<img src="${optimizedSrc}" alt="${alt || ''}"${classAttr} loading="lazy">`;
  });

  // ========================================
  // 開発サーバー設定
  // ========================================
  eleventyConfig.setServerOptions({
    port: 8080,
    watch: ['css/**/*.css', 'js/**/*.js'],
  });

  // ========================================
  // ディレクトリ設定
  // ========================================
  return {
    // 環境変数から pathPrefix を設定
    // 空文字列の場合は pathPrefix を設定しない（ローカル開発用）
    ...(pathPrefix && { pathPrefix }),

    dir: {
      input: '.',
      output: '_site',
      includes: '_includes',
      layouts: '_includes/layouts',
      data: '_data',
    },
    // テンプレートエンジンの優先順位
    markdownTemplateEngine: 'njk',
    htmlTemplateEngine: 'njk',
    templateFormats: ['njk', 'md', 'html'],
  };
};
