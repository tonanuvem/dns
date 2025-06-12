#!/bin/bash

# Mensagem de commit padrão
MENSAGEM=${1:-"atualizando"}

echo "🔄 Adicionando arquivos..."
git add .

echo "✅ Fazendo commit com mensagem: '$MENSAGEM'"
git commit -m "$MENSAGEM"

echo "📤 Enviando para o GitHub..."
git push

echo "🎉 Atualização concluída!"
