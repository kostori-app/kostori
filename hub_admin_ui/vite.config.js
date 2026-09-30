import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

// 产物直接输出到 Flutter 的 assets/hub_admin/，随应用一起打包。
// - 不做外置下载：省下的体积有限，却要引入「远程代码 → 管理面」的风险面，
//   而且断网时管理页会直接不可用。
// - 文件名固定（不做 hash）：服务端用显式路由表按名字取资源，
//   不需要解析文件名，也就没有任何来自请求的路径拼接。
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
    // 本地开发时把 API 代理到正在运行的 Hub 管理端口
    port: 5273,
    proxy: {
      '/api': { target: 'http://127.0.0.1:9200', changeOrigin: true },
    },
  },
});
