# ============================================================================
#  SETUP DO AMBIENTE NOHA - Windows (PowerShell)
#  Cole UMA vez no PowerShell e nunca mais. Baixa as contas da organizacao
#  noha-agencia a que voce tem acesso. Os agentes vem do plugin "noha".
#
#  Uso (PowerShell):
#    iex (irm 'https://raw.githubusercontent.com/noha-agencia/noha-setup/main/noha-setup.ps1')
#
#  A prova de silencio: cada passo e best-effort e SEMPRE explica o desfecho.
# ============================================================================
$ORG = 'noha-agencia'
$ErrorActionPreference = 'Continue'

function Ok($m)   { Write-Host $m -ForegroundColor Green }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Err($m)  { Write-Host $m -ForegroundColor Red }

Write-Host ""
Write-Host "Preparando o ambiente Noha..." -ForegroundColor Cyan

# --- pre-requisitos (falha SEMPRE com mensagem clara) -----------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Err "[X] Falta o Git. Instale em https://git-scm.com/download/win e cole este comando de novo."
  return
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Err "[X] Falta o GitHub CLI. Instale em https://cli.github.com/  depois rode:  gh auth login"
  return
}
gh auth status 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
  Err "[X] Voce nao esta logado no GitHub."
  Write-Host "    Rode:  gh auth login   (GitHub.com -> HTTPS -> login no navegador)"
  Write-Host "    Depois cole este MESMO comando de novo."
  return
}

$base     = Join-Path $HOME 'Noha'
$contasDir = Join-Path $base 'contas'
New-Item -ItemType Directory -Force -Path $contasDir | Out-Null

# --- 1) Cerebro noha-os: SO para quem administra (dono). Time nao precisa. ---
$temOs = $false
$osDir = Join-Path $base 'os'
if (Test-Path (Join-Path $osDir '.git')) {
  $temOs = $true
  git -C $osDir pull -q 2>$null | Out-Null
} else {
  gh repo view "$ORG/noha-os" 1>$null 2>$null
  if ($LASTEXITCODE -eq 0) {
    git clone -q "https://github.com/$ORG/noha-os.git" $osDir 2>$null
    if ($LASTEXITCODE -eq 0) { $temOs = $true }
  }
}

# --- 2) Contas da organizacao a que VOCE tem acesso -------------------------
Write-Host "Procurando as contas liberadas para voce na organizacao $ORG..."
$contas = @(gh api --paginate "/user/repos?per_page=100" --jq '.[].full_name' 2>$null |
  Where-Object { $_ -like "$ORG/conta-*" } |
  ForEach-Object { $_ -replace "^$ORG/", '' } |
  Sort-Object -Unique)
if ($contas.Count -eq 0) {
  $contas = @(gh repo list $ORG --limit 200 --json name --jq '.[].name' 2>$null |
    Where-Object { $_ -like 'conta-*' } | Sort-Object -Unique)
}

$n = 0
foreach ($repo in $contas) {
  $pasta = Join-Path $contasDir ($repo -replace '^conta-', '')
  if (Test-Path (Join-Path $pasta '.git')) {
    git -C $pasta pull -q 2>$null | Out-Null
  } else {
    git clone -q "https://github.com/$ORG/$repo.git" $pasta 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "  [ok] $repo"; $n++ }
    else { Warn "  [!] $repo: nao consegui baixar (acesso?) - sigo com o resto" }
  }
}

# --- 2.5) Plugins (agentes + memoria + metodo) ------------------------------
if (Get-Command claude -ErrorAction SilentlyContinue) {
  Write-Host "Ativando plugins do time (noha + claude-mem + superpowers)..."
  claude plugin marketplace add thedotmack/claude-mem        *> $null
  claude plugin marketplace add obra/superpowers-marketplace *> $null
  claude plugin marketplace add "$ORG/noha-plugin"           *> $null
  claude plugin install claude-mem@thedotmack                *> $null
  claude plugin install superpowers@superpowers-marketplace  *> $null
  claude plugin install noha@noha                            *> $null
  Ok "  [ok] plugins prontos (atualizam sozinhos)"
}

# --- 3) Desfecho (3 casos, SEMPRE explicito) --------------------------------
Write-Host ""
if ($temOs) {
  Copy-Item (Join-Path $osDir 'templates\ambiente\CLAUDE.md')     (Join-Path $base 'CLAUDE.md')          -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path (Join-Path $base '.claude') | Out-Null
  Copy-Item (Join-Path $osDir 'templates\ambiente\settings.json') (Join-Path $base '.claude\settings.json') -Force -ErrorAction SilentlyContinue
  $produtosDir = Join-Path $base 'produtos'
  New-Item -ItemType Directory -Force -Path $produtosDir | Out-Null
  foreach ($par in @('dash:noha-ads-manager-v2','nohaverso:nohaverso','content-engine:noha-content','ai-creator:ai-creator-engine')) {
    $nome = $par.Split(':')[0]; $repo = $par.Split(':')[1]
    $dest = Join-Path $produtosDir $nome
    if (-not (Test-Path (Join-Path $dest '.git'))) {
      gh repo view "$ORG/$repo" 1>$null 2>$null
      if ($LASTEXITCODE -eq 0) {
        git clone -q --depth 1 "https://github.com/$ORG/$repo.git" $dest 2>$null
        if ($LASTEXITCODE -eq 0) { Ok "  [produto] $nome" }
      }
    }
  }
  Write-Host ""
  Ok "[ok] Ambiente completo pronto em $base (voce tem o cerebro noha-os)."
  Write-Host "     Abra o Claude Code em $base e converse."
} elseif ($contas.Count -gt 0) {
  Ok "[ok] Pronto! Suas contas estao em $contasDir ($n baixada(s) agora)."
  Write-Host "     Abra o Claude Code em $base e peca em portugues."
  Write-Host "     Os 10 agentes ja vem no plugin ""noha"" - e so conversar."
} else {
  Warn "Quase la - falta liberar seu acesso (NAO e erro no seu computador):"
  Write-Host "  1) Aceite o convite da organizacao ""$ORG"" no GitHub"
  Write-Host "     (chega por e-mail, ou em github.com/$ORG -> aceitar)."
  Write-Host "  2) Se ja aceitou e mesmo assim nao veio conta, avise o Rodrigo:"
  Write-Host "     ele te adiciona ao time (github.com/orgs/$ORG/teams/time)."
  Write-Host "  Depois cole este MESMO comando de novo - ai as contas baixam sozinhas."
}
Write-Host ""
