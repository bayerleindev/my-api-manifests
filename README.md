# my-api manifests

Manifests GitOps da [`my-api`](https://github.com/bayerleindev/my-api), gerenciados pelo Argo CD e executados pelo Argo Rollouts.

## Estrutura

```text
.
├── .github
│   └── workflows
│       └── grafana-dashboards.yml
├── argocd
│   ├── application.yaml
│   ├── k6-operator
│   │   └── application.yaml
│   ├── load-testing
│   │   └── application.yaml
│   └── monitoring
│       ├── README.md
│       ├── application.yaml
│       ├── values.yaml
│       └── grafana
│           ├── dashboards
│           ├── generate-kustomization.sh
│           └── kustomization.yaml
├── load-testing
│   ├── README.md
│   ├── cronjob.yaml
│   ├── kustomization.yaml
│   ├── rbac.yaml
│   └── test-definition.yaml
└── k8s
    ├── analysis-template.yaml
    ├── kustomization.yaml
    ├── monitoring.yaml
    └── rollout.yaml
```

O Rollout usa NGINX para dividir o tráfego nos pesos 5%, 10%, 50% e 100%. Cada etapa executa uma análise automática e, se aprovada, aguarda promoção manual.

O `AnalysisTemplate` consulta somente as métricas dos Pods da revisão canary e
avalia o endpoint `/api/system`. Em cada peso são feitas três medições, com
intervalo de 30 segundos:

- taxa de respostas 5xx menor que 1%;
- latência p95 menor que 500 ms;
- pelo menos 20 requisições do canary na janela de 2 minutos.

Duas violações entre as três medições abortam o rollout. Tráfego insuficiente
produz um resultado inconclusivo e mantém o rollout pausado. Três erros
consecutivos ao consultar o Prometheus também abortam o rollout.

O manifesto `k8s/monitoring.yaml` cria um Service dedicado às métricas da API e um `ServiceMonitor` para o Prometheus do `kube-prometheus-stack`. Instale a stack de monitoring antes de sincronizar esse recurso, pois o CRD `ServiceMonitor` precisa existir no cluster.

## Pré-requisitos

- Argo CD instalado no namespace `argocd`;
- Argo Rollouts instalado no cluster;
- NGINX Ingress Controller instalado;
- imagem `system-info-api:blue` disponível nos nós do kind.

Para carregar a imagem local no kind:

```bash
kind load docker-image system-info-api:blue --name rollouts-lab
```

## Cadastrar no Argo CD

```bash
kubectl apply --filename argocd/application.yaml
```

A sincronização é manual para permitir experimentos locais sem `selfHeal` sobrescrever mudanças feitas com `set image`.

```bash
argocd app sync my-api
```

A aplicação do Argo CD acompanha a branch `main` deste repositório e renderiza a pasta `k8s` com Kustomize.

## Acompanhar e promover

```bash
kubectl argo rollouts get rollout my-api --watch
kubectl argo rollouts promote my-api
```

Para gerar aproximadamente 10 requisições por segundo durante a análise, na
raiz do laboratório execute:

```bash
./scripts/call-my-api.sh
```

A taxa pode ser alterada com `REQUESTS_PER_SECOND`, por exemplo:

```bash
REQUESTS_PER_SECOND=20 ./scripts/call-my-api.sh
```

Acompanhe os objetos criados para cada gate:

```bash
kubectl get analysisruns --watch
kubectl describe analysisrun <nome>
```

Uma análise aprovada leva o rollout até a pausa manual seguinte. Use `promote`
para avançar apenas depois de revisar o resultado. Se a análise abortar o
rollout, corrija ou publique uma nova imagem antes de tentar novamente.

## Atualizar por GitOps

Altere `spec.template.spec.containers[].image` em `k8s/rollout.yaml`, faça commit e push e sincronize a aplicação:

```bash
argocd app sync my-api
```

## Monitoring

O diretório [`argocd/monitoring`](argocd/monitoring/README.md) instala o `kube-prometheus-stack` pelo Argo CD e provisiona dashboards JSON no Grafana por GitOps.

## Teste de carga diário

O diretório [`load-testing`](load-testing/README.md) instala, por GitOps, um
teste k6 de 10 requisições por segundo durante 20 minutos. A execução ocorre
diariamente às 18:10 no fuso `America/Sao_Paulo`, percorre o Ingress real e
envia os resultados ao Prometheus para o dashboard **my-api / k6 Daily Load
Test**.

As Applications são separadas porque o Operator precisa instalar o CRD
`TestRun` antes da sincronização dos recursos de teste:

```bash
kubectl apply --filename argocd/k6-operator/application.yaml
kubectl apply --filename argocd/load-testing/application.yaml
```
