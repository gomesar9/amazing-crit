# CLAUDE.md — Addon para World of Warcraft: Forever

## O que este addon faz

**AmazingCrit** (pasta `AmazingCrit/`, comando `/amazingcrit`, SavedVariables `AmazingCritDB`) toca um som (`.ogg`) quando o jogador acerta um golpe crítico. O som varia conforme a arma. Dois modos (`ns.MODES`, `Config.lua`): **source** (preciso, padrão) — som por fonte certa (`ns.SOURCE_CATEGORIES`: escola do dano crítico no alvo, cura crítica em player/pet/alvo, crítico/esmagador recebido); **weapon** (heurístico, para jogar solo) — som por arma (`ns.WEAPON_CATEGORIES`). Som próprio só para **arco** e **espada**; o resto usa `Sounds/generic.ogg` até o usuário entregar os sons (um por escola/fonte). Nomes antigos: "CritRag" (até v0.6.0) e "CritSound", este abandonado (conflita com o addon CritSound de Nexio, GPLv3, em `docs/references/CritSound/` (local, fora do git) só como referência — não copiar código nem sons).

### Estado atual (v0.6.0, 2026-10-22)

- Servidor do Forever voltou em 2026-10-22; v0.4.0 (arco, espada, painel) testada em jogo e OK pelo usuário. Comportamento ainda não confirmado em jogo fica marcado `-- TODO: verificar no Forever`.
- Sons: originais em `assets/sounds/` (.mp3), convertidos com ffmpeg para `AmazingCrit/Sounds/*.ogg` (comando no `README.md` raiz).
- Pacote: `./package.sh` (local, fora do git) gera `dist/AmazingCrit-<versão>.zip` só com `.toc`, `.lua` e `Sounds/*.ogg`; valida que todo arquivo do TOC existe.
- Deploy: `./deploy.sh` (local, fora do git via `.gitignore`; rsync de `AmazingCrit/` para `<WoW>/_classic_beta_/Interface/AddOns/AmazingCrit/`; `WOW_DIR`/`GAME_DIR` sobrescrevem o destino). Após o lançamento, trocar `GAME_DIR` para a pasta real do Forever.
- **Testes offline: `lua tests/run.lua`** (Lua 5.4 local). Stubs da API do WoW + carga dos arquivos na ordem do TOC + disparo de eventos. Rodar antes de considerar qualquer mudança pronta; ao adicionar API nova, adicionar o stub correspondente. Stubs não substituem teste em jogo.
- **Código-fonte da UI do Forever** (melhor que a wiki para Settings/FrameXML): https://github.com/Gethe/wow-ui-source/tree/forever (branch `forever` = 1.60.1). Ex.: `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua`.
- Painel de opções: `AmazingCrit/Options.lua`, layout vertical nativo do Settings (plano em `docs/UI_PLAN.md`).
- `luacheck` não está instalado (luarocks falha por falta de `lua.h`; precisa `liblua5.1-dev` via sudo). Enquanto isso: `lua -e "assert(loadfile('arquivo.lua'))"`.

### Abordagem técnica (confirmada no beta 1.60.1)

1. **`COMBAT_LOG_EVENT_UNFILTERED` está BLOQUEADO para addons no Forever** (confirmado em jogo; igual ao Midnight 12.0.0, onde registrar o evento dispara `ADDON_ACTION_FORBIDDEN`). Não usar CLEU.
2. **Detecção: `UNIT_COMBAT`** — payload `unitTarget, action, flagText, amount, schoolMask` (sem flags de secret na doc do Forever). Confirmado em jogo: chega `WOUND CRITICAL` legível fora de raid. `action`: `WOUND`/`HEAL`/`ENERGIZE`/...; `flagText`: `CRITICAL`/`CRUSHING`/`GLANCING`/...; `schoolMask` = bits de `Enum.Damageclass.Mask*`. Checar `issecretvalue()` antes de comparar qualquer campo.
   - **O que é certo**: unidade que recebeu, tipo (dano/cura), crítico, valor, escola. **O que NÃO é**: quem causou, e ataque comum vs habilidade (ambos "físico"). Decisão do usuário: modo **source** usa só informação certa; modo **weapon** é a heurística, para jogar solo.
   - Modo source: `RegisterEvent("UNIT_COMBAT")` (todas as unidades; filtra `player`/`pet`/`target`). Modo weapon: `RegisterUnitEvent(..., "target")`.
   - Cura no alvo ignorada se alvo for você/pet (`UnitIsUnit`, pode ser secret → tratado como "não"). Dano no alvo só se hostil; cura no alvo só se não hostil.
   - Valor mínimo (`minDamage`, `/amazingcrit min`) vale para dano e cura.
3. **Modo weapon — arma inferida pelo estado de ataque automático**: `START_AUTOREPEAT_SPELL`/`STOP_AUTOREPEAT_SPELL` (Auto Shot → slot ranged) e `PLAYER_ENTER_COMBAT`/`PLAYER_LEAVE_COMBAT` (auto-attack corpo a corpo → main-hand, senão off-hand). Sem ataque automático ativo → não toca. Confirmado em jogo para Auto Shot e corpo a corpo; varinha/arremesso ainda não.
   - Druida (`UnitClassBase`) em qualquer forma (`GetShapeshiftFormInfo` isActive, atualizado em `UPDATE_SHAPESHIFT_FORM`) → não toca.
   - Categoria por slot via `GetInventoryItemID` + `C_Item.GetItemInfoInstant` (classID 6º, subClassID 7º retorno; não precisa de cache de servidor) + `Enum.ItemWeaponSubclass` (tabela `SUBCLASS_TO_CATEGORY` em `Core.lua`; 1M/2M na mesma categoria; vara de pesca e Warglaive/Generic/Bearclaw/Catclaw fora). Cache atualizado em `PLAYER_EQUIPMENT_CHANGED`.
4. **Tocar o som**: `PlaySoundFile("Interface\\AddOns\\AmazingCrit\\Sounds\\<arquivo>", canal)` (aceita .ogg e .mp3; canal Master/SFX). Throttle por `GetTime()`. Arquivo de som novo: reiniciar o cliente.
5. **Opções (SavedVariables, `Config.lua`, versão 4)**: `enabled`, `mode`, `channel`, `throttle`, `minDamage`, `sources = { <fonte> = bool }`, `categories = { <arma> = bool }`, `sounds = { bow, sword, generic }` (chave sem entrada usa `generic`); migração v3→v4 põe usuários antigos em `mode = "weapon"`; versionadas por `version` com merge de defaults. Slash: `/amazingcrit` abre o painel; `/amazingcrit [status|on|off|mode source|weapon|test <som>|min <n>|channel master|sfx]`.

## Contexto do projeto

Este repositório é um addon em Lua para **World of Warcraft: Forever** (o "Classic+" da Blizzard, patch 1.60.x; lançamento em 4 de novembro de 2026, beta aberto de 17 de setembro a 21 de outubro de 2026).

Fato mais importante antes de escrever qualquer linha: **Forever NÃO usa a API do Classic Era.** Forever e o WoW moderno (Midnight, 12.1.x) são dois "game types" da mesma família de código Mainline (Forever chamava-se internamente "Camelot"). Forever compartilha a arquitetura de UI e a grande maioria das APIs do 12.1.5, incluindo as restrições de "addon disarmament" e **secret values**. Conteúdo, classes, talentos de nível 60 etc. são estilo vanilla; a _API_ é moderna.

## Fonte de verdade

- API geral: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
- Widget API: https://warcraft.wiki.gg/wiki/Widget_API
- Eventos: https://warcraft.wiki.gg/wiki/Events
- Mudanças específicas do Forever: https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes
- Secret values: https://warcraft.wiki.gg/wiki/Secret_Values e https://warcraft.wiki.gg/wiki/Secret_aspects
- Página do jogo: https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever

Regras para uso da API:

1. **Nunca confie na memória para assinaturas de funções.** Antes de usar uma função, busque a página `API:<nome>` na wiki e confira parâmetros, retornos e se ela existe no Forever (procure a marca "forever" / 1.60 na página).
2. Prefira os namespaces `C_*` modernos. Exemplos de substituições obrigatórias:
   - `UnitAura` → `C_UnitAuras.GetAuraDataByIndex` / `GetAuraDataBySlot` / `AuraUtil.ForEachAura`
   - `GetSpellInfo` → `C_Spell.GetSpellInfo`
   - `GetItemInfo` → `C_Item.GetItemInfo`
   - `GetAddOnMetadata` → `C_AddOns.GetAddOnMetadata`
   - `IsAddOnLoaded` → `C_AddOns.IsAddOnLoaded`
   - `GetContainerItemInfo` → `C_Container.GetContainerItemInfo`
   - `SendChatMessage` → `C_ChatInfo.SendChatMessage`
   - `InterfaceOptions_AddCategory` → `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterAddOnCategory`
3. Se não tiver certeza de que uma API existe no Forever, marque com `-- TODO: verificar no Forever` e me avise em vez de inventar.
4. A beta ainda muda a API a cada build. Ao começar uma sessão, releia a página de API changes acima.

## Fatos técnicos do Forever (1.60.1)

- **Interface version no TOC: `16001`** (`## Interface: 16001`).
- Cliente beta instala em `_classic_beta_/Interface/AddOns/<Addon>/`. Após o lançamento, confirmar a pasta real do Forever.
- Sufixo de TOC por jogo: `MeuAddon_Forever.toc` (alias de `_Camelot`). Variável `[Game]` também aceita `Forever`.
- **Secret values**: dentro de encontros/combate, muitos valores viram "secrets" — podem ser exibidos (passados a FontString, StatusBar etc.) mas **não** podem ser comparados, usados em aritmética, concatenados ou indexados. Tentar isso gera erro de Lua. Trate qualquer dado de unidade/aura/combate como potencialmente secreto; use `issecretvalue()` e, quando possível, delegue a exibição a widgets nativos (AuraContainer/AuraButton do 12.1.0 existem no Forever).
- `GetFrameStrata` pode retornar secret para frames com o aspecto `FrameStrata`.
- GUIDs de criaturas/pets/objetos têm server ID e spawn ID ofuscados (estáveis só na sessão). Nunca use GUID para inferir layer.
- `C_ChatInfo.SendChatMessage` com `SAY`, `YELL` e `EMOTE` exige hardware event fora de instâncias. Contas trial não enviam addon messages.
- `C_PvP.IsWarModeFeatureEnabled()` retorna false. Edit Mode existe e salva layouts por tipo de UI.
- Os frames padrão de Forever (player, target, pet, ToT, totem, focus, cabeçalho do minimapa) foram reskinados e reorganizados; não assuma a hierarquia de filhos do retail ao ancorar/skinar.
- O `require` adicionado ao Lua foi renomeado para `import`.

## Regras gerais do ambiente Lua do WoW

- Lua 5.1 customizado: sem `io`, `os.exit`, `require`, `loadfile`, `dofile`; sem acesso a disco/rede. `string`, `table`, `math` existem, com extras da Blizzard (`strsplit`, `tContains`, `wipe`, `CreateFrame`, `C_Timer`, etc.).
- Cada arquivo recebe `local ADDON_NAME, ns = ...`. Use a tabela `ns` como namespace privado; **não polua o ambiente global** (um único global com o nome do addon, no máximo).
- Ciclo de vida: `ADDON_LOADED` (SavedVariables disponíveis) → `PLAYER_LOGIN` (API de personagem pronta) → `PLAYER_ENTERING_WORLD`. Inicialize em `PLAYER_LOGIN` salvo necessidade específica.
- Eventos: `frame:RegisterEvent(...)` + `frame:SetScript("OnEvent", ...)`; prefira `RegisterUnitEvent` quando filtrar por unidade. Nunca faça trabalho pesado em `OnUpdate`; use `C_Timer.After`/`NewTicker`.
- **Taint e combate**: não toque em frames/funções protegidas durante `InCombatLockdown()`; enfileire mudanças para `PLAYER_REGEN_ENABLED`. Botões de ação/alvo usam `SecureActionButtonTemplate` e são configurados só fora de combate. Não escreva em globais da Blizzard (`_G.XYZ = ...`) nem hookeie funções seguras diretamente — use `hooksecurefunc`.
- SavedVariables: declare `## SavedVariables: MeuAddonDB` e `## SavedVariablesPerCharacter:`. Faça versionamento/migração do DB com defaults.
- Localização: strings em `Locales/enUS.lua` como padrão + `ptBR.lua`; nunca hardcode texto de UI nos arquivos de lógica.
- Comandos de slash via `SLASH_MEUADDON1 = "/meuaddon"; SlashCmdList.MEUADDON = fn`.
- Bibliotecas: só adicione Ace3/LibStub etc. se houver ganho real; use versões com suporte a Forever (AceDB-3.0 ≥ rev. 36). Embutir em `Libs/` e listar no TOC.

## Estrutura esperada

```
MeuAddon/
  MeuAddon.toc            # Interface: 16001, Title, Notes, Author, Version, SavedVariables, lista de arquivos em ordem
  Core.lua                # inicialização, eventos, namespace ns
  Config.lua              # defaults e migração de SavedVariables
  Options.lua             # painel em Settings
  UI/                     # frames (XML ou Lua)
  Locales/enUS.lua, ptBR.lua
  Libs/                   # opcional
  .luacheckrc             # std = lua51 + globais do WoW
  .pkgmeta                # opcional, para packager
  CHANGELOG.md
```

## Qualidade e testes

- Rode `luacheck .` antes de considerar algo pronto (configure `.luacheckrc` com os globais do WoW; sem `_G` indiscriminado).
- No jogo: `/console scriptErrors 1`, `/reload`, `/fstack` (inspecionar frames), `/etrace` (eventos), `/dump expr`. Recomende BugSack + BugGrabber e DevTool ao usuário para depuração.
- Teste cenários de combate e de encontro: muitos bugs de secret value só aparecem em raid/dungeon.
- Mudanças de API na beta são frequentes: em cada feature, anote quais APIs foram usadas para facilitar auditoria quando um novo build sair.

## Como trabalhar comigo

- Antes de implementar uma feature, liste em poucas linhas quais eventos e APIs vai usar e confirme-os na wiki; só então escreva código.
- Código em Lua com nomes em inglês; comentários e conversa comigo em português.
- Entregue arquivos completos, não trechos, quando criar ou reescrever um arquivo.
- Não adicione dependências, frameworks ou abstrações além do pedido.
