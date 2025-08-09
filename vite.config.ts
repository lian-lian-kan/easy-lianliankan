import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  base: '/demo/',
  server: {
    port: 50511,
    host: true
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets'
  }
})
