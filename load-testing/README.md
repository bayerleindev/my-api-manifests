# Teste de carga agendado

Esta pasta define o teste diário da `my-api` executado pelo k6 Operator.

## Comportamento

- execução todos os dias às `01:00` no fuso `America/Sao_Paulo`;
- tolerância de 15 minutos caso o cluster esteja indisponível no horário;
- uma única execução por vez;
- 10 requisições por segundo durante 20 minutos;
- acesso pelo Ingress interno com `Host: my-api.local`, atingindo stable e canary conforme o peso atual do rollout;
- falha quando a taxa de requisições com erro for igual ou superior a 1%;
- falha quando a latência p95 for igual ou superior a 500 ms;
- envio de métricas ao Prometheus por Remote Write.

O `CronJob` mantém o `TestRun` concluído e seus Jobs para diagnóstico. Na
execução seguinte, ele remove o resultado anterior antes de criar o novo. Se o
teste anterior ainda estiver em andamento, a nova execução falha sem
interrompê-lo.

Como este laboratório usa Kind, o MacBook e o cluster precisam estar ligados
às 01:00. Se o cluster voltar depois de 01:15, aquela execução será ignorada.

## Instalação pelo Argo CD

Instale primeiro o Operator, porque a segunda Application depende do CRD
`TestRun`:

```bash
kubectl apply --filename argocd/k6-operator/application.yaml
kubectl wait \
  --namespace k6-operator-system \
  --for=condition=Available \
  deployment/k6-operator-controller-manager \
  --timeout=180s

kubectl apply --filename argocd/load-testing/application.yaml
```

Confira a sincronização:

```bash
argocd app get k6-operator
argocd app get my-api-load-testing
kubectl get cronjob --namespace load-testing
```

## Executar agora

Para validar o fluxo sem esperar até 01:00, crie um Job a partir do CronJob:

```bash
kubectl create job \
  --namespace load-testing \
  --from=cronjob/my-api-daily \
  my-api-daily-test-$(date +%s)
```

Acompanhe o teste:

```bash
kubectl get testrun --namespace load-testing --watch
kubectl get jobs,pods --namespace load-testing
kubectl logs --namespace load-testing job/my-api-daily-test-<timestamp> --follow
```

O estágio `finished` indica conclusão bem-sucedida. O estágio `error` indica
falha de infraestrutura ou violação dos thresholds. Para encontrar os Jobs dos
runners:

```bash
kubectl get jobs \
  --namespace load-testing \
  --selector k6_cr=my-api-daily
```

## Dashboard

O teste envia métricas `k6_*` para o Prometheus em `monitoring`. O dashboard
provisionado **my-api / k6 Daily Load Test** apresenta:

- volume e taxa de requisições;
- taxa de erros e checks aprovados;
- latências p90, p95 e p99;
- quantidade de virtual users.

O Prometheus mantém 14 dias de métricas. O armazenamento continua efêmero:
recriar o Prometheus ou o cluster pode apagar o histórico.
