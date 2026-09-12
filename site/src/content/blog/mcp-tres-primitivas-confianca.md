---
title: "MCP tem 3 primitivas — e cada uma carrega um nível de confiança diferente"
date: 2026-08-28
author: "Equipe Codisec"
tags: [mcp, ai-security, protocolo, integração]
excerpt: "Tools, resources e prompts não são só nomes técnicos — são três modelos de confiança diferentes dentro do mesmo protocolo. Entender qual é qual evita expor mais do que devia."
---

Se você já conectou um LLM numa ferramenta externa via function calling manual, sabe a dor: escrever schema JSON à mão, manter sincronizado com a API real, e torcer pra ninguém esquecer de atualizar os dois lados. O Model Context Protocol (MCP) nasceu pra resolver exatamente isso — virou, na prática, o jeito padrão do mercado de plugar um modelo em serviço externo sem reinventar a integração toda vez.

O que interessa pra quem pensa em segurança não é a sintaxe do protocolo — é a separação de responsabilidade que ele formaliza.

**As 3 primitivas, e quem decide usar cada uma:**

- **Tools** — controladas pelo modelo. O LLM decide quando chamar, com quais argumentos. É a primitiva mais poderosa e a que mais precisa de validação de entrada.
- **Resources** — controladas pela aplicação. Dados só-leitura que o app decide expor, não o modelo. Menor superfície de risco, mas ainda é dado saindo do seu perímetro.
- **Prompts** — controladas pelo usuário. Instruções pré-prontas que a pessoa escolhe invocar, não o modelo sozinho.

Essa distinção existe porque cada uma responde uma pergunta de confiança diferente: "o modelo pode decidir sozinho fazer isso?" (tools), "isso é só leitura?" (resources), "o humano está no controle explícito?" (prompts). Misturar essas categorias — por exemplo, expor uma escrita destrutiva como se fosse um resource — é onde a maioria dos MCP servers mal implementados quebra o próprio modelo de segurança sem perceber.

**Na prática:**

```python
@server.tool()
def delete_document(doc_id: str) -> str:
    """Remove um documento pelo ID."""
    ...
```

Se isso for chamado só porque o modelo "achou que fazia sentido" numa conversa, sem nenhuma camada de confirmação, você tem uma tool poderosa demais rodando sem o freio que o próprio protocolo sugere.

Pra quem quer ir além da teoria: a Anthropic tem um curso gratuito — Introduction to Model Context Protocol — que constrói um MCP server do zero com o SDK Python, cobrindo as três primitivas na prática (10 aulas, ~1h, com quiz e badge de conclusão).
