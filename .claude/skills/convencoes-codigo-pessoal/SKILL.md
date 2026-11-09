---
name: convencoes-codigo-pessoal
description: Minhas convenções pessoais de código Python — nomenclatura em português, docstrings e como evitar padrões de escrita genéricos de IA. Use sempre que estiver escrevendo ou revisando código Python, neste ou em qualquer outro projeto meu.
---

# Convenções de código pessoal

## Nomenclatura
- Nome de variável e função em português, específico ao que faz.
- Nada de nome genérico tipo `processar_dados` ou `handle_utils` — o nome descreve a transformação exata (ex: `calcular_nota_composta`, `preco_teto_graham_blended`).

## Docstrings
- Toda função pública tem docstring explicando o que recebe, o que devolve e por que existe — não repete o nome da função em prosa.
- Comentário inline só registra uma decisão não óbvia. Nunca narra uma linha que já é clara sozinha.

## Estilo geral
- PEP 8.
- Sem padrão de escrita de IA: nada de "este código implementa uma solução robusta e abrangente para...", nada de emoji em comentário, nada de resumo redundante no fim de um arquivo.
- Type hint onde ajuda a leitura, não como enfeite.
