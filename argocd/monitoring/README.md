# Monitoring

Esta pasta instala o `kube-prometheus-stack` com Prometheus, Grafana, Alertmanager, exporters e dashboards do Kubernetes, gerenciados pelo Argo CD.

## Estrutura

```text
argocd/monitoring/
├── README.md
├── application.yaml
├── values.yaml
└── grafana/
    ├── dashboards/
    │   └── canary-overview.json
    ├── generate-kustomization.sh
    └── kustomization.yaml
```

## Como o deploy acontece

A `Application` usa duas fontes:

1. o chart oficial `kube-prometheus-stack`, fixado na versão `92.10.1`;
2. este repositório, que fornece `argocd/monitoring/values.yaml` ao Helm e renderiza `argocd/monitoring/grafana` com Kustomize.

O Argo CD combina as duas fontes e instala tudo no namespace `monitoring`. A sincronização é automática, com `prune` e `selfHeal`. `ServerSideApply` está habilitado para suportar os CRDs grandes do Prometheus Operator.

Pré-requisitos:

- Argo CD 2.6 ou superior, por causa do suporte a múltiplas fontes;
- Kubernetes 1.25 ou superior;
- acesso do cluster aos registries públicos usados pelo chart.

Cadastre a aplicação uma vez:

```bash
kubectl apply --filename argocd/monitoring/application.yaml
```

Acompanhe a instalação:

```bash
argocd app get kube-prometheus-stack
kubectl get pods --namespace monitoring --watch
```

Depois disso, commits na pasta `argocd/monitoring` são detectados e aplicados automaticamente pelo Argo CD.

## Acessar o Grafana

```bash
kubectl port-forward \
  --namespace monitoring \
  service/kube-prometheus-stack-grafana \
  3000:80
```

Acesse `http://localhost:3000`. O usuário é `admin`. Obtenha a senha gerada pelo chart:

```bash
kubectl get secret kube-prometheus-stack-grafana \
  --namespace monitoring \
  --output jsonpath='{.data.admin-password}' | base64 --decode
echo
```

## Dashboards JSON como código

O Grafana possui um sidecar que observa, no namespace `monitoring`, ConfigMaps com o label:

```yaml
grafana_dashboard: "1"
```

O Kustomize transforma os arquivos listados em `grafana/kustomization.yaml` no ConfigMap `grafana-custom-dashboards`. O sidecar copia os JSONs para o diretório de provisionamento e o Grafana os carrega ou atualiza automaticamente.

Para adicionar um dashboard:

1. no Grafana, use **Share > Export > Export as JSON**;
2. salve o arquivo em `argocd/monitoring/grafana/dashboards/<nome>.json`;
3. faça commit e push.

O workflow `.github/workflows/grafana-dashboards.yml` valida todos os JSONs com `jq`, atualiza a lista do `configMapGenerator` e cria um segundo commit quando necessário. O Argo CD sincroniza esse commit e o dashboard aparece no Grafana sem importação manual.

Para gerar a lista antes do commit:

```bash
./argocd/monitoring/grafana/generate-kustomization.sh
kubectl kustomize argocd/monitoring/grafana
```

Use nomes de arquivo simples, em minúsculas e sem espaços. Não edite dashboards provisionados diretamente na interface: `allowUiUpdates` está desabilitado e o Git permanece como fonte de verdade.

O `configMapGenerator` agrupa os JSONs em um ConfigMap, cujo limite total é aproximadamente 1 MiB. Quando o conjunto crescer, divida os dashboards entre mais de um `configMapGenerator`.

## Métricas da my-api

Os manifests da aplicação criam o Service `my-api-metrics` no namespace `default` e um `ServiceMonitor` no namespace `monitoring`. O Prometheus consulta `/actuator/prometheus` a cada 15 segundos.

O Service seleciona somente Pods com `monitoring: enabled`. Essa marca existe nas revisões instrumentadas e impede que uma versão antiga, sem `/actuator/prometheus`, apareça como target indisponível durante um rollout.

Os monitores de `kube-controller-manager`, `kube-scheduler`, `etcd` e `kube-proxy` estão desabilitados neste laboratório. No Kind, esses componentes publicam métricas apenas no loopback do nó e não podem ser alcançados pelo Prometheus executado como Pod.

Confirme o endpoint descoberto em **Status > Targets** no Prometheus:

```bash
kubectl port-forward \
  --namespace monitoring \
  service/kube-prometheus-stack-prometheus \
  9090:9090
```

Depois acesse `http://localhost:9090/targets` e procure por `serviceMonitor/monitoring/my-api`.
