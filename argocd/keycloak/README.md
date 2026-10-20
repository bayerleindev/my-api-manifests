# Keycloak no lab

Esta pasta instala o Keycloak `26.8.1` e um PostgreSQL persistente no namespace
`keycloak`. A instalação é gerenciada por `application.yaml`, que sincroniza os
recursos da subpasta `manifests`.

O desenho foi adaptado do
[Quickstart oficial do Keycloak](https://www.keycloak.org/getting-started/getting-started-kube).
Ele é adequado ao lab local e ainda não representa uma configuração de produção:
não há TLS, alta disponibilidade nem backup do banco.

## Instalar

As credenciais não ficam no Git. Crie os Secrets antes de cadastrar a
Application:

```bash
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic keycloak-admin \
  --namespace keycloak \
  --from-literal=username=admin \
  --from-literal=password='<senha-admin>'

kubectl create secret generic keycloak-db \
  --namespace keycloak \
  --from-literal=username=keycloak \
  --from-literal=password='<senha-banco>' \
  --from-literal=database=keycloak

kubectl apply --filename argocd/keycloak/application.yaml
```

O Argo CD cria os demais recursos e mantém o estado sincronizado com a branch
`main`:

```bash
kubectl get applications.argoproj.io keycloak --namespace argocd
kubectl get pods --namespace keycloak --watch
```

## Acessar

Neste cluster Kind, as portas HTTP/HTTPS do Ingress Controller não estão
publicadas no host. Use o port-forward:

```bash
kubectl port-forward --namespace keycloak service/keycloak 8081:8080
```

Abra <http://localhost:8081/admin/>.

O manifesto também cria o host `keycloak.local` no Ingress. Para usá-lo,
publique a porta do Ingress Controller no host e adicione ao `/etc/hosts`:

```text
127.0.0.1 keycloak.local
```

Então abra <http://keycloak.local/admin/>. Em ambos os casos, entre com o
usuário armazenado no Secret `keycloak-admin`.

## Próximo passo: SSO do Argo CD

Após validar a instalação, crie no Keycloak um realm próprio para o lab, um
client OIDC para o Argo CD e os grupos de equipe. Só então configure `oidc.config`
e `policy.csv` no Argo CD. Mantenha o login local de administrador até o fluxo
OIDC e o RBAC terem sido testados.

