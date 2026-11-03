import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [react()],
  // allow importing shared/design-tokens from the repo root
  server: { fs: { allow: ['..'] } },
});
