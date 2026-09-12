---
title: "O que muda no seu CI quando você começa a rodar gitleaks de verdade"
date: 2026-07-14
tags: [secrets, gitleaks, git, ci-cd, devsecops]
excerpt: "Da primeira PR quebrada até o time parar de commitar secret sem querer — o que esperar nas primeiras duas semanas."
author: "Equipe Codisec"
---

Secret vazado em repositório não é um problema hipotético — é um dos
vetores de comprometimento mais comuns e mais baratos de explorar: uma
`AWS_SECRET_ACCESS_KEY` ou uma connection string de banco commitada por
engano, às vezes removida do arquivo no commit seguinte, mas ainda viva no
histórico do Git pra sempre. gitleaks é a ferramenta mais adotada pra
pegar isso antes que vá parar num repositório público (ou num repositório
privado que, mais cedo ou mais tarde, alguém vai clonar sem pensar duas
vezes).

## O que gitleaks realmente faz

gitleaks varre o conteúdo de arquivos — e, se você pedir, o histórico
inteiro de commits — procurando por padrões que batem com formatos
conhecidos de credencial: chaves de API da AWS, tokens do GitHub, chaves
privadas SSH, connection strings com senha embutida, entre várias outras.
Ele roda local (`gitleaks detect`) ou como parte do CI, escaneando cada
push ou pull request antes do merge.

O detalhe que costuma surpreender quem está adotando agora: **remover o
secret do arquivo atual não remove ele do repositório.** Se a chave foi
commitada em algum ponto do histórico, ela continua recuperável via
`git log`/`git show` daquele commit específico, mesmo que o arquivo de hoje
esteja limpo. Rotacionar a credencial vazada é sempre o primeiro passo —
antes até de limpar o histórico.

## O que muda nas primeiras duas semanas

Pela nossa experiência ajudando times a ligar isso pela primeira vez, o
padrão é bem previsível:

**Dias 1–3: a primeira onda de PRs quebrados.** Quase sempre são
falso-positivo de verdade (uma string de teste que parece uma chave) ou
segredo de ambiente de desenvolvimento que "todo mundo sabia" mas nunca
devia ter ido pro Git. É o momento de decidir: allowlist pontual pra
falso-positivo genuíno, rotação imediata pra segredo real.

**Semana 1: perguntas sobre o histórico.** Alguém pergunta "e os secrets
que já estão commitados desde antes?" — porque o CI só pega o que entra
daqui pra frente. Escanear o histórico completo (`gitleaks detect
--log-opts="--all"` ou equivalente) costuma revelar pelo menos um achado
antigo esquecido. Vale rodar isso uma vez, de propósito, fora do fluxo
normal de CI.

**Semana 2: o time para de commitar secret por hábito.** Não porque
decorou as regras, mas porque o CI vermelho vira feedback imediato — o
mesmo mecanismo que faz um time parar de quebrar teste sem querer.

## Bota a mão na massa

Montamos um lab com um repositório Git real contendo uma AWS access key e
uma senha de banco de dados commitadas por engano — inclusive no
histórico, não só no arquivo atual. Você usa gitleaks pra encontrar os dois
achados, remove do código, e confirma na prática por que só editar o
arquivo atual não é suficiente.

→ [Lab: Secrets Vazados em Repositório — Detecção com gitleaks](/labs/devsecops-secrets-detection)
