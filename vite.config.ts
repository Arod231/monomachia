import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';

export default defineConfig({
  plugins: [viteSingleFile()],
  build: {
    target: 'es2020',
    assetsInlineLimit: 100000000,
    chunkSizeWarningLimit: 4000,
    cssCodeSplit: false,
  },
  test: {
    environment: 'node',
    // The Node tests (tests/**/*.test.mjs) run on Node's own runner: npm run test:node.
    include: ['tests/**/*.test.ts'],
  },
});
