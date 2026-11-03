/** Tokens come from Figma via shared/design-tokens — do not hard-code colours here. */
module.exports = {
  presets: [require('../shared/design-tokens/dist/tailwind-preset.cjs')],
  content: ['./index.html', './src/**/*.{ts,tsx}'],
};
