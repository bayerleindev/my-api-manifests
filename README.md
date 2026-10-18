# my-api manifests

Manifests GitOps da `my-api`, gerenciados pelo Argo CD e executados pelo Argo Rollouts.

## Estrutura

```text
.
├── argocd
│   └── application.yaml
└── k8s
    ├── kustomization.yaml
    └── rollout.yaml
```

O Rollout usa NGINX para dividir o tráfego nos pesos 5%, 10%, 50% e 100%. Cada etapa possui promoção manual.

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

## Acompanhar e promover

```bash
kubectl argo rollouts get rollout my-api --watch
kubectl argo rollouts promote my-api
```

## Atualizar por GitOps

Altere `spec.template.spec.containers[].image` em `k8s/rollout.yaml`, faça commit e push e sincronize a aplicação:

```bash
argocd app sync my-api
```
