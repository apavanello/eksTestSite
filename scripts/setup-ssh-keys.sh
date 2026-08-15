#!/usr/bin/env bash
# Gera chave SSH ed25519 (autenticação GitHub + assinatura de commits) e configura o git.
# Rode uma vez por máquina. Seguro de rodar de novo: pula o que já estiver pronto.
#
# Depois de rodar, suba a chave pública DUAS vezes em:
#   github.com → Settings → SSH and GPG keys → New SSH key (seção SSH keys, NÃO a GPG)
#     1) title "auth"    · key type "Authentication Key"
#     2) title "signing" · key type "Signing Key" (mesma chave, papel diferente)
set -euo pipefail

KEY="$HOME/.ssh/id_ed25519"
EMAIL="${1:-}"

if [ -z "$EMAIL" ]; then
  read -rp "Email para o comentário da chave (o usado nos commits do git): " EMAIL
  [ -z "$EMAIL" ] && { echo "email obrigatório (ou passe como argumento)"; exit 1; }
fi

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

# 1. gerar (sem sobrescrever chave existente)
if [ -f "$KEY" ]; then
  echo "chave já existe: $KEY (pulando geração)"
else
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY"
  echo "chave gerada: $KEY"
fi

# 2. agente
if [ -z "${SSH_AUTH_SOCK:-}" ] || ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add "$KEY" 2>/dev/null || echo "aviso: agente não aceitou a chave (ok se já estiver adicionada)"

# 3. git: assinar commits com a chave ssh (não precisa de PGP)
git config --global gpg.format ssh
git config --global user.signingkey "$KEY.pub"
git config --global commit.gpgsign true
echo "git configurado para assinar commits com $KEY.pub"

# 4. allowed_signers: permite ao git VERIFICAR assinaturas ssh localmente
#    (o GitHub verifica sozinho e mostra "Verified"; isto é para o
#     git log --show-signature não reclamar)
SIGNERS="$HOME/.ssh/allowed_signers"
if ! grep -qF "$(awk '{print $2" "$3}' "$KEY.pub")" "$SIGNERS" 2>/dev/null; then
  echo "$EMAIL $(cat "$KEY.pub")" >> "$SIGNERS"
fi
chmod 600 "$SIGNERS"
git config --global gpg.ssh.allowedSignersFile "$SIGNERS"
echo "allowed_signers em $SIGNERS"

# 5. ssh config: agente pega a chave sozinho
if ! grep -q "AddKeysToAgent" "$HOME/.ssh/config" 2>/dev/null; then
  cat >> "$HOME/.ssh/config" <<'EOF'

Host github.com
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
EOF
  echo "~/.ssh/config: entrada github.com adicionada"
fi

# 6. mostrar a pública para colar no GitHub
echo
echo "═══ COPIE ESTA CHAVE E COLE NO GITHUB 2x (auth + signing) ═══"
echo
cat "$KEY.pub"
echo
echo "════════════════════════════════════════════════════════════"
echo
echo "Após subir a chave, teste:"
echo "  ssh -T git@github.com                          # esperado: Hi <seu-user>!"
echo "  git commit --allow-empty -m teste && git log --show-signature -1"
