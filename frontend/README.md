# Frontend do Gerenciador DNS

Este é o frontend do Gerenciador DNS, construído com React e Vite.

## Requisitos

- Node.js 16+
- npm 7+

## Instalação

1. Instale as dependências:
```bash
npm install
```

2. Configure as variáveis de ambiente:
Crie um arquivo `.env` na raiz do projeto com o seguinte conteúdo:
```
VITE_API_URL=http://localhost:3000
```

## Desenvolvimento

Para iniciar o servidor de desenvolvimento:
```bash
npm run dev
```

## Build

Para criar uma build de produção:
```bash
npm run build
```

## Estrutura do Projeto

- `src/` - Código fonte
  - `components/` - Componentes React
  - `dataProvider.js` - Provedor de dados para o React Admin
  - `App.jsx` - Componente principal
  - `index.jsx` - Ponto de entrada
  - `index.css` - Estilos globais 