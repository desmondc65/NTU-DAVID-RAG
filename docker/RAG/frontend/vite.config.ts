import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(() => {
  const proxyTarget = process.env.VITE_API_PROXY_TARGET || 'http://localhost:5000'

  return {
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
