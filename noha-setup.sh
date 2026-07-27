#!/bin/bash
# ============================================================================
# SETUP DO AMBIENTE NOHA — cole UMA vez no Terminal e nunca mais.
# Baixa as contas (clientes) da organização noha-agencia a que você tem acesso.
# Os agentes vêm do plugin "noha" (instalado aqui) — nada fica preso a uma conta.
#
# Uso:  bash <(curl -fsSL https://raw.githubusercontent.com/noha-agencia/noha-setup/main/noha-setup.sh)
#   ou: bash ~/Noha/os/bin/noha-setup.sh   (para atualizar)
#
# IMPORTANTE: este script é "à prova de silêncio" — NÃO usa `set -e`, então ele
# nunca aborta sem explicar. Cada passo é best-effort e sempre imprime o desfecho.
# ============================================================================
ORG="noha-agencia"
say() { printf '%s\n' "$*"; }

say "🌊 Preparando o ambiente Noha..."

# --- pré-requisitos (falha SEMPRE com mensagem clara) -----------------------
command -v git >/dev/null 2>&1 || { say "❌ Falta o git. Rode: xcode-select --install  (e cole este comando de novo)"; exit 1; }
command -v gh  >/dev/null 2>&1 || { say "❌ Falta o GitHub CLI. Rode: brew install gh  → depois: gh auth login"; exit 1; }
if ! gh auth status >/dev/null 2>&1; then
  say "❌ Você não está logado no GitHub."
  say "   Rode:  gh auth login   (escolha GitHub.com → HTTPS → login no navegador)"
  say "   Depois cole este MESMO comando de novo."
  exit 1
fi

mkdir -p "$HOME/Noha/contas"

# --- 1) Cérebro noha-os: SÓ para quem administra (dono). O time não precisa. -
TEM_OS=0
if [ -d "$HOME/Noha/os/.git" ]; then
  TEM_OS=1
  git -C "$HOME/Noha/os" pull -q 2>/dev/null || true
elif gh repo view "$ORG/noha-os" >/dev/null 2>&1; then
  git clone -q "https://github.com/$ORG/noha-os.git" "$HOME/Noha/os" 2>/dev/null && TEM_OS=1 || true
fi

# --- 2) Contas da organização a que VOCÊ tem acesso -------------------------
say "🔎 Procurando as contas liberadas para você na organização $ORG…"
CONTAS=$(gh api --paginate "/user/repos?per_page=100" --jq '.[].full_name' 2>/dev/null | grep "^$ORG/conta-" | sed "s#$ORG/##" | sort -u)
if [ -z "$CONTAS" ]; then
  CONTAS=$(gh repo list "$ORG" --limit 200 --json name --jq '.[].name' 2>/dev/null | grep '^conta-' | sort -u)
fi

N=0
if [ -n "$CONTAS" ]; then
  for repo in $CONTAS; do
    pasta="$HOME/Noha/contas/${repo#conta-}"
    if [ -d "$pasta/.git" ]; then
      git -C "$pasta" pull -q 2>/dev/null || say "  ⚠️  $repo: pull falhou (a gente resolve depois)"
    elif git clone -q "https://github.com/$ORG/$repo.git" "$pasta" 2>/dev/null; then
      say "  ✅ $repo"
      N=$((N + 1))
    else
      say "  ⚠️  $repo: não consegui baixar (acesso?) — sigo com o resto"
    fi
  done
fi

# --- 2.5) Plugins que fazem o Claude trabalhar melhor gastando MENOS token ---
if command -v claude >/dev/null 2>&1; then
  say "🧩 Ativando plugins do time (noha + claude-mem + superpowers)…"
  claude plugin marketplace add thedotmack/claude-mem        >/dev/null 2>&1 || true
  claude plugin marketplace add obra/superpowers-marketplace >/dev/null 2>&1 || true
  claude plugin marketplace add "$ORG/noha-plugin"           >/dev/null 2>&1 || true
  claude plugin install claude-mem@thedotmack                >/dev/null 2>&1 || true
  claude plugin install superpowers@superpowers-marketplace  >/dev/null 2>&1 || true
  claude plugin install noha@noha                            >/dev/null 2>&1 || true
  say "  ✅ plugins prontos (atualizam sozinhos)"
fi

# --- 3) Desfecho (3 casos, SEMPRE explícito) --------------------------------
say ""
if [ "$TEM_OS" = "1" ]; then
  cp "$HOME/Noha/os/templates/ambiente/CLAUDE.md"      "$HOME/Noha/CLAUDE.md"              2>/dev/null || true
  mkdir -p "$HOME/Noha/.claude"
  cp "$HOME/Noha/os/templates/ambiente/settings.json"  "$HOME/Noha/.claude/settings.json"  2>/dev/null || true
  chmod +x "$HOME/Noha/os/bin/"*.sh 2>/dev/null || true
  mkdir -p "$HOME/Noha/produtos"
  for par in "dash:noha-ads-manager-v2" "nohaverso:nohaverso" "content-engine:noha-content" "ai-creator:ai-creator-engine"; do
    nome="${par%%:*}"; repo="${par##*:}"
    if [ ! -d "$HOME/Noha/produtos/$nome/.git" ] && gh repo view "$ORG/$repo" >/dev/null 2>&1; then
      git clone -q --depth 1 "https://github.com/$ORG/$repo.git" "$HOME/Noha/produtos/$nome" 2>/dev/null && say "  🛠️  produto: $nome"
    fi
  done
  say ""
  say "✅ Ambiente completo pronto em ~/Noha (você tem o cérebro noha-os)."
  say "   • agentes via plugin   • clientes em contas/   • ferramentas em produtos/"
  say "   Abra o Claude Code em ~/Noha e converse."
elif [ -n "$CONTAS" ]; then
  say "✅ Pronto! Suas contas estão em ~/Noha/contas/ ($N baixada(s) agora)."
  say "   Abra o Claude Code em ~/Noha e peça em português."
  say "   Os 10 agentes já vêm no plugin \"noha\" — é só conversar."
else
  say "🔓 Quase lá — falta liberar seu acesso (NÃO é erro no seu computador):"
  say "   1) Aceite o convite da organização \"$ORG\" no GitHub"
  say "      (chega por e-mail, ou em github.com/$ORG → aceitar)."
  say "   2) Se já aceitou e mesmo assim não veio conta, avise o Rodrigo:"
  say "      ele te adiciona ao time (github.com/orgs/$ORG/teams/time)."
  say "   Depois cole este MESMO comando de novo — aí as contas baixam sozinhas."
fi
