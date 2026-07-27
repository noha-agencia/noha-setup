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

# --- 2.5) Plugins: agentes da Noha + as skills que eles mandam usar ----------
# Cada passo reporta o desfecho REAL. Nada de dizer "pronto" quando falhou.
if command -v claude >/dev/null 2>&1; then
  say "🧩 Ativando plugins do time…"
  FALHOU=""
  # repo:plugin@marketplace:rótulo
  #
  # ATENÇÃO: o nome do marketplace vem do marketplace.json dele, NÃO do nome do
  # repositório — e às vezes os dois diferem (claude-ads e ui-ux-pro-max abaixo).
  # Conferir com: claude plugin marketplace add <repo>  (ele imprime o nome real).
  for tri in \
    "thedotmack/claude-mem:claude-mem@thedotmack:memória entre sessões" \
    "obra/superpowers-marketplace:superpowers@superpowers-marketplace:método de trabalho" \
    "$ORG/noha-plugin:noha@noha:agentes + skills da Noha" \
    "affaan-m/everything-claude-code:ecc@ecc:skills de conteúdo e pesquisa" \
    "AgriciDaniel/claude-ads:claude-ads@ai-marketing-hub-claude-ads:skills de mídia paga (ads-*)" \
    "nextlevelbuilder/ui-ux-pro-max-skill:ui-ux-pro-max@ui-ux-pro-max-skill:design de interface" \
    "pbakaus/impeccable:impeccable@impeccable:linguagem de design de frontend"
  do
    mkt="${tri%%:*}"; resto="${tri#*:}"; plug="${resto%%:*}"; rotulo="${resto#*:}"
    nome_mkt="${plug#*@}"
    claude plugin marketplace add "$mkt" >/dev/null 2>&1
    # `add` não refaz o cache de um marketplace já adicionado: sem este update,
    # quem já tinha a versão antiga instala a antiga de novo e o script diz "ok".
    claude plugin marketplace update "$nome_mkt" >/dev/null 2>&1
    if claude plugin install "$plug" >/dev/null 2>&1; then
      say "  ✅ $rotulo"
    else
      say "  ❌ $rotulo — NÃO instalou ($plug)"
      FALHOU="$FALHOU $plug"
    fi
  done
  if [ -n "$FALHOU" ]; then
    say ""
    say "  ⚠️  Alguns plugins não instalaram:$FALHOU"
    say "     Se um deles for 'noha@noha', você não vai receber os agentes nem as"
    say "     skills da agência. Causa mais comum: falta acesso ao repo privado."
    say "     Confira com:  gh repo view $ORG/noha-plugin"
    say "     Se der 'not found', peça ao Rodrigo pra te adicionar ao time."
  fi
fi

# --- 2.6) Motor do nohacopy (opcional: só quem tem acesso ao repo) -----------
# A skill nohacopy vem no plugin e já funciona sem isto (modo leve). Este repo
# adiciona o modo completo: transcrição de áudio na GPU e extração de frames.
if [ -d "$HOME/Noha/nohacopy/.git" ]; then
  git -C "$HOME/Noha/nohacopy" pull -q 2>/dev/null || say "  ⚠️  nohacopy: pull falhou (a gente resolve depois)"
elif gh repo view "$ORG/nohacopy" >/dev/null 2>&1; then
  if git clone -q "https://github.com/$ORG/nohacopy.git" "$HOME/Noha/nohacopy" 2>/dev/null; then
    say "  ✍️  nohacopy: motor de copy baixado (modo completo)"
    if ! command -v ffmpeg >/dev/null 2>&1; then
      say "     ⚠️  falta ffmpeg pra transcrever áudio. Rode: brew install ffmpeg"
    fi
    say "     Para ativar a transcrição: pip install -r ~/Noha/nohacopy/requirements.txt"
  fi
fi

# --- 3) Desfecho (3 casos, SEMPRE explícito) --------------------------------
say ""
if [ "$TEM_OS" = "1" ]; then
  # Estes dois arquivos são sobrescritos pelo template. Guarda cópia antes —
  # quem ajustou algo à mão não perde o trabalho sem aviso.
  mkdir -p "$HOME/Noha/.claude"
  for alvo in "$HOME/Noha/CLAUDE.md" "$HOME/Noha/.claude/settings.json"; do
    case "$alvo" in
      *CLAUDE.md)     origem="$HOME/Noha/os/templates/ambiente/CLAUDE.md";;
      *settings.json) origem="$HOME/Noha/os/templates/ambiente/settings.json";;
    esac
    [ -f "$origem" ] || continue
    if [ -f "$alvo" ] && ! cmp -s "$alvo" "$origem"; then
      cp "$alvo" "$alvo.bak" 2>/dev/null && say "  💾 backup: $(basename "$alvo") → $(basename "$alvo").bak (tinha ajuste local)"
    fi
    cp "$origem" "$alvo" 2>/dev/null || true
  done
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
