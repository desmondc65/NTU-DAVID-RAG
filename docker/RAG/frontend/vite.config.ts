import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// VITE_BASE_PATH embeds a non-root base (e.g. '/rag/') so assets resolve
// correctly when the app is hosted under a prefix by the unified nginx
// proxy. Default '/' keeps the single-container compose working unchanged.
export default defineConfig(() => {
  const proxyTarget = process.env.VITE_API_PROXY_TARGET || 'http://localhost:5000'
  const base = process.env.VITE_BASE_PATH || '/'

  return {
    base,
    plugins: [react()],
    server: {
      host: true,
      proxy: {
        '/api': proxyTarget,
      },
      watch: {
        usePolling: true,
      },
    },
    build: {
      outDir: 'dist',
    },
  }
})
