---
title: "Rodar um MCP server em produção é decidir sua superfície de ataque duas vezes: no transporte e nos roots"
date: 2026-09-12
author: "Equipe Codisec"
tags: [mcp, ai-security, infra, production]
excerpt: "STDIO local não é a mesma decisão de segurança que StreamableHTTP exposto na rede. E roots definem até onde seu servidor pode enxergar o filesystem do host."
---

Depois que o MCP básico funciona local, a próxima pergunta não é "como eu adiciono mais uma tool" — é "como eu boto isso em produção sem abrir uma porta que eu nem sabia que tinha". Duas decisões carregam a maior parte do risco: transporte e roots.

**Transporte: STDIO vs. StreamableHTTP não é só performance**

- **STDIO** — processo local, comunicação por stdin/stdout. Sem rede envolvida, a superfície de ataque é basicamente "quem tem acesso ao processo".
- **StreamableHTTP** — o server vira um serviço de rede de verdade, com sessão e HTTP. É a diferença entre "roda na sua máquina" e "agora isso é infraestrutura que alguém precisa proteger, atualizar e monitorar".

Escolher StreamableHTTP pra escalar horizontalmente atrás de um load balancer é uma decisão legítima — mas é uma decisão de infraestrutura com implicação de segurança, não só um flag de configuração.

**Roots: o limite de filesystem que o server deveria ter desde o primeiro dia**

Roots existem pra resolver um problema já conhecido de quem mexeu com upload de arquivo ou path traversal: sem um limite explícito, "acesso a arquivo" vira "acesso a qualquer arquivo que o processo consiga ler". Definir roots é a versão MCP de uma allowlist de diretório — a mesma lógica de defesa que já vimos [no lab de SSRF](/labs/appsec-ssrf-basics) (nunca confiar no que vem de fora sem checar contra uma lista explícita antes).

**Sampling também tem leitura de segurança:** ele permite que o *server* peça pro *cliente* rodar uma chamada de modelo — inverte o fluxo normal. Um server malicioso ou comprometido pode tentar abusar dessa via. Vale tratar isso com o mesmo ceticismo que qualquer callback externo.

**Pra quem já passa do básico:** [Model Context Protocol: Advanced Topics](https://academy.claude.com/courses/model-context-protocol-advanced-topics) cobre sampling, notificações, roots e as duas famílias de transporte com walkthrough interativo de cada fluxo (11 aulas, ~1h30, com quiz).
