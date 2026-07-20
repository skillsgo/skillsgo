/*
 * [INPUT]: Depends on Vite, React, Tailwind CSS, Fumadocs MDX, and TanStack Start plugins.
 * [OUTPUT]: Provides the development server and prerendered production build configuration.
 * [POS]: Serves as the docs-site build and static deployment composition root.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { tanstackStart } from '@tanstack/react-start/plugin/vite';
import mdx from 'fumadocs-mdx/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 3100,
  },
  plugins: [
    mdx(),
    tailwindcss(),
    tanstackStart({
      spa: {
        enabled: true,
        prerender: {
          enabled: true,
          crawlLinks: true,
        },
      },
      pages: [
        { path: '/' },
        { path: '/docs' },
        { path: '/en' },
        { path: '/en/docs' },
        { path: '/en/llms.txt' },
        { path: '/en/llms-full.txt' },
        { path: '/zh-CN' },
        { path: '/zh-CN/docs' },
        { path: '/zh-CN/llms.txt' },
        { path: '/zh-CN/llms-full.txt' },
        { path: '/api/search' },
        { path: '/llms.txt' },
        { path: '/llms-full.txt' },
      ],
    }),
    react(),
  ],
  resolve: {
    tsconfigPaths: true,
    alias: {
      tslib: 'tslib/tslib.es6.js',
    },
  },
});
