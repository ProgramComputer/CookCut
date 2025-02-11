module.exports = {
  plugins: [
    {
      name: 'removeAttrs',
      params: {
        attrs: ['transform:none']
      }
    },
    'cleanupAttrs',
    'removeDoctype',
    'removeXMLProcInst',
    'removeComments',
    'removeMetadata',
    'removeTitle',
    'removeDesc',
    'removeUselessDefs',
    'removeEditorsNSData',
    'removeEmptyAttrs',
    'removeHiddenElems',
    'removeEmptyText',
    'removeEmptyContainers',
    'removeViewBox',
    'cleanupEnableBackground',
    'minifyStyles',
    'convertStyleToAttrs',
    'convertColors',
    'convertPathData',
    'convertTransform',
    'removeUnknownsAndDefaults',
    'removeNonInheritableGroupAttrs',
    'removeUselessStrokeAndFill',
    'removeUnusedNS',
    'prefixIds',
    'cleanupIDs',
    'cleanupNumericValues',
    'cleanupListOfValues',
    'moveElemsAttrsToGroup',
    'moveGroupAttrsToElems',
    'collapseGroups',
    'removeRasterImages',
    'mergePaths',
    'convertShapeToPath',
    'sortAttrs',
    'sortDefsChildren',
    'removeDimensions',
    {
      name: 'removeAttrs',
      params: {
        attrs: ['style']
      }
    }
  ]
}; 