import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

// 产物输出到 Flutter 的 assets/hub_admin/，随应用一起打包。
// 文件名固定（不 hash）：服务端用显式路由表按名字取资源，
// 于是文件名从不来自请求，也就不存在路径拼接面。
export default defineConfig({
  plugins: [vue()],
  // 相对路径：页面挂在 / 或 /admin 下都能正确解析出 ./app.js
  base: './',
  build: {
    outDir: '../assets/hub_admin',
    emptyOutDir: true,
    target: 'es2020',
    cssCodeSplit: false,
    modulePreload: { polyfill: false },
    reportCompressedSize: true,
    rollupOptions: {
      output: {
        entryFileNames: 'app.js',
        chunkFileNames: 'app-[name].js',
        assetFileNames: 'app.[ext]',
      },
    },
  },
  server: {
    port: 5273,
    // 转发到运行中的 Hub 管理端口
    proxy: {
      '/api': { target: 'http://127.0.0.1:9200', changeOrigin: true },
    },
  },
});
