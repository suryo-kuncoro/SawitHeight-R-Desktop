const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const required = [
  'package.json', 'src/main.js', 'src/preload.js', 'src/renderer/index.html',
  'src/renderer/styles.css', 'src/renderer/app.js', 'r/pipeline.R',
  'r/check_environment.R', 'r/install_packages.R', 'assets/icon.ico',
  '.github/workflows/build-windows.yml', 'docs/SOURCE_MAPPING.md', 'docs/reference_tutorial.html'
];
let failed = false;
for (const item of required) {
  const full = path.join(root, item);
  if (!fs.existsSync(full) || fs.statSync(full).size === 0) {
    console.error(`MISSING: ${item}`);
    failed = true;
  } else {
    console.log(`OK: ${item}`);
  }
}
process.exit(failed ? 1 : 0);
