---
title: "IDOR continua sendo o achado #1 em pentest de API — por que a gente ainda erra isso"
date: 2026-08-13
tags: [idor, api, owasp-top10, broken-access-control]
excerpt: "Checagem de autorização por objeto é simples de explicar e fácil de esquecer de implementar. Um raio-x de onde essa falha mora de verdade no código."
author: "Equipe Codisec"
---

Se você já leu um relatório de pentest de API nos últimos anos, provavelmente
já viu a sigla IDOR — Insecure Direct Object Reference. É consistentemente um
dos achados mais comuns em avaliações de segurança de API, e faz parte do
A01:2021 (Broken Access Control) no OWASP Top 10. A parte curiosa não é que
ela exista: é que a explicação cabe em duas frases, e ainda assim continua
aparecendo em código novo, escrito por gente que sabe exatamente o que é
IDOR.

## O que é, de verdade

Um endpoint recebe um identificador — `/api/users/2/profile`,
`/api/invoices/8231`, `/api/orders/4471/cancel` — e usa esse identificador
pra buscar um registro. Até aqui, nada de errado. O problema aparece quando
o servidor confia que, se alguém está autenticado, qualquer ID que essa
pessoa mandar é um ID que ela tem permissão de acessar.

```
GET /api/users/1/profile   → seu perfil
GET /api/users/2/profile   → perfil de outra pessoa, sem nenhuma checagem extra
```

Não tem exploração sofisticada aqui. Não tem bypass de autenticação, não
tem token forjado. A pessoa está logada, do jeito certo, e só troca um
número na URL.

## Por que continua acontecendo

Na nossa experiência, a causa raiz quase nunca é "o time não sabe o que é
IDOR". É:

- **A checagem de autenticação e a checagem de autorização são tratadas
  como a mesma coisa.** O middleware confirma que existe um usuário válido
  por trás do token — e o código do endpoint assume que isso já é
  suficiente pra liberar o acesso ao recurso pedido.
- **Falta um padrão consistente.** Em APIs grandes, cada endpoint costuma
  implementar sua própria checagem (ou nenhuma), porque não existe uma
  camada central que force "todo recurso passa por uma verificação de
  propriedade antes de ser retornado".
- **Testes cobrem o caminho feliz.** É fácil escrever um teste que confirma
  que o usuário 1 vê o perfil do usuário 1. É bem menos comum alguém
  escrever o teste que confirma que o usuário 1 **não** vê o perfil do
  usuário 2.

## A correção é sempre a mesma forma

```python
@app.get("/api/users/<int:user_id>/profile")
def get_profile(user_id):
    if user_id != current_user_id():
        abort(403)
    ...
```

Uma linha. O difícil não é escrever essa linha — é lembrar de escrevê-la em
todo endpoint que recebe um identificador de recurso, incluindo naquele
endpoint que "só um admin ia usar mesmo" e que seis meses depois virou
público.

## Bota a mão na massa

Escrevemos um lab prático em cima exatamente desse cenário: uma API Flask
com IDOR real, onde você primeiro confirma a exploração (acessa dados de
outro usuário só trocando o ID) e depois aplica a correção você mesmo,
direto no código, dentro de um container local.

→ [Lab: IDOR em API REST — Acesso Indevido a Dados de Terceiros](/labs/appsec-idor-api)
