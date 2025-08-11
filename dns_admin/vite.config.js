import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    open: true,
    // ✅ Adicionado: Lista de hosts permitidos para acessar o servidor de desenvolvimento
    allowedHosts: [
      'localhost', // Sempre bom ter localhost
      '127.0.0.1', // E o IP local
      'teste-api.aluno.lab.tonanuvem.com', // Seu subdomínio específico
      'aluno.lab.tonanuvem.com' // Se você também acessar a raiz desse subdomínio
    ]
  },
  build: {
    outDir: 'build',
    sourcemap: true
  }
})
