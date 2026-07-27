# Noha — Setup do ambiente (1 comando)

Baixa as contas de cliente que **você tem acesso** na organização **noha-agencia**
e ativa os plugins do time (agentes + memória + método). Rode **uma vez**;
para atualizar depois, é só rodar de novo.

## Antes de começar (só na 1ª vez)

1. **Git** — macOS: já vem (ou `xcode-select --install`) · **Windows:** https://git-scm.com/download/win
2. **GitHub CLI (gh)** — https://cli.github.com
3. Faça login no GitHub: `gh auth login`
4. **Aceite o convite** da organização **noha-agencia** (chega por e-mail, ou em github.com/noha-agencia).

## macOS / Linux — cole no **Terminal**

```
bash <(curl -fsSL https://raw.githubusercontent.com/noha-agencia/noha-setup/main/noha-setup.sh)
```

## Windows — cole no **PowerShell**

```
iex (irm 'https://raw.githubusercontent.com/noha-agencia/noha-setup/main/noha-setup.ps1')
```

> No Windows, use o **PowerShell** (não o `cmd`). O script bash de macOS **não**
> funciona no PowerShell — cada sistema tem o seu comando acima.

---

Se aparecer **"falta liberar seu acesso"**, não é erro no seu computador: é só
aceitar o convite da organização e rodar o mesmo comando de novo. O script nunca
trava sem explicar — ele sempre diz o que falta.
