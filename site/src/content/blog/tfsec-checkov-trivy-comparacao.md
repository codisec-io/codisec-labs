---
title: "tfsec, checkov ou trivy: qual scanner de IaC faz sentido no seu pipeline"
date: 2026-07-29
tags: [iac, terraform, tfsec, trivy, devsecops, ci-cd]
excerpt: "Comparamos os três em cima de cenários reais de Terraform e de imagem Docker, achado por achado, pra decidir qual entra no seu CI sem virar ruído."
author: "Equipe Codisec"
---

"Qual scanner a gente usa?" é uma pergunta que aparece cedo em qualquer time
que está montando um pipeline de DevSecOps — e a resposta curta é: depende
do que você está escaneando. tfsec, checkov e trivy não são
substitutos diretos um do outro, apesar de aparecerem lado a lado em quase
toda lista de "ferramentas de segurança pra IaC".

## O que cada um faz de verdade

**tfsec** é focado em Terraform. Ele entende a sintaxe HCL nativamente e
tem regras específicas pra más práticas comuns em provedores como AWS,
Azure e GCP — bucket S3 público, Security Group aberto pro mundo
(`0.0.0.0/0`), criptografia de disco desligada. Rápido, sem dependências
externas, e o formato das mensagens é direto: arquivo, linha, o que está
errado, por que importa.

**checkov**, da Bridgecrew (hoje parte da Palo Alto), escaneia um espectro
bem mais amplo: Terraform, CloudFormation, Kubernetes manifests,
Dockerfile, Helm, Serverless Framework. A vantagem é cobertura — um único
scanner pra várias linguagens de infraestrutura. A contrapartida é que,
justamente por ser genérico, o conjunto de regras pra Terraform
especificamente costuma ser menos afinado que o do tfsec.

**trivy**, da Aqua Security, nasceu como scanner de vulnerabilidades em
imagens de container (CVEs em pacotes do sistema operacional e em
dependências de linguagem) e cresceu pra também escanear IaC, arquivos de
configuração e até repositórios Git em busca de secrets. Se seu pipeline
já builda imagens Docker, trivy tende a aparecer de qualquer forma —
a pergunta é se ele também assume o papel de scanner de Terraform.

## Onde cada um ganha, na prática

| Cenário | Melhor opção | Por quê |
|---|---|---|
| Só Terraform, quer o scanner mais rápido e com menos falso positivo | tfsec | Regras específicas de Terraform, sem overhead de suportar N formatos |
| Infra heterogênea (Terraform + K8s + Dockerfile) num só relatório | checkov | Um scanner, um formato de saída, cobre tudo |
| Já usa trivy pra escanear imagem de container no CI | trivy | Adicionar o scan de IaC no mesmo passo evita instalar uma ferramenta a mais |
| Time pequeno, quer o setup mais simples de manter | tfsec ou trivy | checkov tem mais configuração pra afinar (é o preço da cobertura ampla) |

## O erro mais comum ao adotar qualquer um dos três

Não é escolher a ferramenta errada — é rodar o scanner sem antes decidir o
que vira **erro que quebra o pipeline** e o que vira **aviso**. Os três
saem da caixa com dezenas de regras ativas, boa parte delas relevante só em
certos contextos. Ativar tudo como bloqueante no primeiro dia normalmente
resulta em um PR travado por um achado de severidade baixa e num time que,
duas semanas depois, começa a ignorar o scanner inteiro. O caminho que
funciona: começar bloqueando só severidade alta/crítica, e subir o rigor
conforme o backlog de achados existentes for resolvido.

## Bota a mão na massa

Temos dois labs que colocam isso em prática com achados reais:

→ [Lab: Segurança em IaC com tfsec](/labs/devsecops-iac-terraform-tfsec) —
um projeto Terraform com bucket S3 público e Security Group aberto ao
mundo, pra você achar e corrigir.

→ [Lab: Container Scanning com trivy](/labs/devsecops-container-scan-trivy)
— uma imagem Docker com CVEs conhecidas numa base desatualizada, pra você
escanear, entender a severidade e corrigir atualizando a imagem.
