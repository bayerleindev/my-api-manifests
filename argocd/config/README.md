# Configuração OIDC e RBAC do Argo CD

Os arquivos deste diretório registram a integração do Argo CD com o realm
`canary-lab` do Keycloak e o acesso administrativo da equipe de plataforma.

Eles são patches de merge, e não ConfigMaps completos. Isso preserva as demais
chaves criadas durante a instalação do Argo CD.

## Aplicar

Mantenha o port-forward do Keycloak acessível aos containers do Kind:

```bash
kubectl port-forward \
  --address 0.0.0.0 \
  --namespace keycloak \
  service/keycloak \
  8081:8080
```

Depois execute, na raiz do repositório:

```bash
./argocd/config/apply.sh
```

O client OIDC é público e usa PKCE, portanto não existe client secret para
armazenar no repositório.

## Política inicial

O `policy.default` é intencionalmente omitido. Usuários autenticados podem
entrar no Argo CD, mas não recebem acesso a Applications ou projetos por
padrão.

O único grupo global configurado é:

```text
/argocd/platform-admins -> role:admin
```

Os acessos das equipes são definidos nos roles dos respectivos AppProjects,
como em `argocd/projects/team-my-api.yaml`.

O usuário local `admin` do Argo CD deve permanecer habilitado como acesso de
emergência enquanto este ambiente for um laboratório.

