const svgToPng = require('svg-to-png');
const path = require('path');

const inputPath = path.resolve(__dirname, 'assets/icon/logo.svg');
const outputDir = path.resolve(__dirname, 'assets/icon');

svgToPng.convert(inputPath, outputDir, {
    defaultWidth: 1024,
    defaultHeight: 1024,
    compress: true
}).then(() => {
    console.log('Successfully converted logo.svg to logo.png');
}).catch(err => {
    console.error('Error converting SVG:', err);
}); 