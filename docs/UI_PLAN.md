# Plano — Painel de opções do AmazingCrit (v0.4.0)

> **Status: implementado em 2026-10-21** (`AmazingCrit/Options.lua`, testes em `tests/run.lua`). APIs do Settings conferidas no código da UI, branch `forever` 1.60.1 build 70450 — os itens "não documentados" abaixo existem lá. Falta só o checklist do lançamento. `AddonCompartmentFunc` não foi feito.

## Contexto
Hoje toda configuração é via `/amazingcrit ...`. Objetivo: painel em **Opções > AddOns > AmazingCrit** usando o layout vertical nativo do Settings (decisão do usuário, 2026-10-21), com liga/desliga por arma. Beta encerrado: **não há teste em jogo até 2026-11-04** → validação offline com stubs + checklist para o lançamento.

## Layout

```
Opções > AddOns > AmazingCrit
[x] Ativado
Canal de áudio        [ Master v ]        (Master, SFX)
Dano mínimo     0 ====o===== 5000         (passo 50; 0 = qualquer crítico)
Intervalo mínimo 0 ==o===== 1.0 s         (passo 0.05; throttle)
— Armas —
[x] Arco      [ Testar ]
[x] Espada    [ Testar ]
```
Botão "Defaults" nativo restaura os padrões.

## APIs (wiki `Settings_API` é stub — tudo abaixo marcado `-- TODO: verificar no Forever`)
- Confirmadas na wiki (assinatura): `Settings.RegisterVerticalLayoutCategory(name)`, `Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, variableType, name, defaultValue)`, `Settings.RegisterAddOnCategory(category)`, `Settings.OpenToCategory(category|id)`.
- Inferidas de exemplo: `Settings.CreateCheckbox(category, setting, tooltip)`, `Settings.CreateSliderOptions(min, max, step)`, `Settings.CreateSlider(category, setting, options, tooltip)`.
- Não documentadas (conferir no código do FrameXML 12.1.x / Forever quando possível): `Settings.CreateDropdown` + `Settings.CreateControlTextContainer`, `CreateSettingsListSectionHeaderInitializer`, `CreateSettingsButtonInitializer`, `setting:SetValueChangedCallback`, `category:GetID()`, `MinimalSliderWithSteppersMixin.Label.Right`.
- Plano B se dropdown/botão falharem: canal só via slash; teste via slash (`/amazingcrit test bow`).

## Mudanças por arquivo
- `Config.lua` — `DB_VERSION = 2`; novo `categories = { bow = true, sword = true }` em defaults; `Migrate`: v1→v2 só aplica defaults (merge já cobre).
- `Core.lua`
  - Expor `ns.PlayCrit`, `ns.UpdateEnabled` (funções locais viram campos de `ns`).
  - `PlayCrit` / `UNIT_COMBAT`: respeitar `ns.db.categories[category]`.
  - `PLAYER_LOGIN`: chamar `ns.InitOptions()` depois do DB.
  - Slash: sem argumento → `Settings.OpenToCategory(ns.optionsCategory:GetID())`; `status` → texto atual; demais comandos iguais.
- **Novo `Options.lua`** (TOC: depois de `Config.lua`, antes de `Core.lua`) — `ns.InitOptions()`:
  - `RegisterAddOnSetting` direto sobre `AmazingCritDB` para `enabled`, `channel`, `minDamage`, `throttle`; `categories.bow`/`categories.sword` com `variableTbl = AmazingCritDB.categories`. Variáveis únicas: `"AmazingCrit_enabled"` etc.
  - Callback de `enabled` → `ns.UpdateEnabled()`.
  - Botões "Testar" → `ns.PlayCrit(cat, true)`.
  - Guarda `ns.optionsCategory`.
- `Locales/enUS.lua`, `ptBR.lua` — rótulos e tooltips (`OPT_ENABLED`, `OPT_CHANNEL`, `OPT_MIN_DAMAGE`, `OPT_THROTTLE`, `OPT_WEAPONS`, `OPT_BOW`, `OPT_SWORD`, `OPT_TEST`, + `_TT`).
- `AmazingCrit.toc` — incluir `Options.lua`; versão 0.4.0. Opcional: `## AddonCompartmentFunc` (TODO verificar no Forever).
- `.luacheckrc` — `Settings`, `CreateSettingsButtonInitializer`, `CreateSettingsListSectionHeaderInitializer`, `MinimalSliderWithSteppersMixin`.
- `README.md`, `CHANGELOG.md` — painel + APIs usadas.

## Validação offline (sem cliente)
- **Novo `tests/run.lua`** (fora do addon, não vai no deploy): stubs mínimos de `CreateFrame`, `Settings.*`, `Enum`, `GetInventoryItemID`, `C_Item.GetItemInfoInstant`, `PlaySoundFile` (registra chamadas), `UnitCanAttack`, `GetTime`, `issecretvalue`, `GetLocale`, `strsplit/strtrim/strlower`, `CopyTable`.
  - Carrega arquivos na ordem do TOC com `(ADDON_NAME, ns)` como varargs.
  - Dispara `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTER_COMBAT` → `UNIT_COMBAT("target","WOUND","CRITICAL",500,1)` e verifica `PlaySoundFile` com `sword.ogg`; casos: `categories.sword=false` (não toca), `minDamage=600` (não toca), valor secreto (não erra), Auto Shot + arco (toca `bow.ogg`).
  - Verifica que o painel registra os settings sem erro.
- Rodar: `lua tests/run.lua` (Lua 5.4 local; atenção a diferenças 5.1, ex.: `unpack`).

## Checklist no lançamento (2026-11-04)
1. Ajustar `GAME_DIR` do `deploy.sh`; deploy; reiniciar cliente.
2. Painel aparece em Opções > AddOns; cada controle salva após `/reload`; "Defaults" restaura.
3. Dropdown de canal e botões "Testar" funcionam (senão aplicar plano B).
4. Desmarcar "Espada" → crítico de espada não toca; repetir cenários da v0.3.0.
5. Resolver todos os `-- TODO: verificar no Forever` (inclui eventos de ataque automático e slot 18).
