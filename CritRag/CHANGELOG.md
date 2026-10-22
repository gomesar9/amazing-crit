# Changelog

## 0.5.1 — 2026-10-22

- Slider de dano mínimo com passos variáveis: 0–50 de 5 em 5, até 100 de 10 em 10, até 1000 de 50 em 50, até 5000 de 100 em 100 (74 posições).
- Implementado com `Settings.RegisterProxySetting`: o slider anda sobre o índice da lista e mostra o dano real. Valores fora da lista definidos por `/critrag min <dano>` são mantidos; o slider mostra o passo mais próximo.

## 0.5.0 — 2026-10-22

- Todas as armas do jogo classificadas: espada, machado, maça, adaga, arma de punho, arma de haste, cajado (corpo a corpo); arco, arma de fogo, besta, varinha, arremesso (tiro automático). 1M e 2M compartilham categoria.
- Som genérico (`Sounds/generic.ogg`, por enquanto cópia do som de espada) para armas sem som próprio.
- Druida em qualquer forma é ignorado (ataques de urso/gato não usam a arma).
- Painel: liga/desliga para cada tipo de arma; seção "Sons" com botões Testar para arco, espada e genérico.
- `/critrag test <arma>|generic`.
- SavedVariables v3 (novas categorias e `sounds.generic`, migração automática).
- Varinha e arremesso dependem de `START_AUTOREPEAT_SPELL` — não testado em jogo.

### APIs novas

- `UnitClassBase`, `GetNumShapeshiftForms`, `GetShapeshiftFormInfo` (2º retorno `isActive`), evento `UPDATE_SHAPESHIFT_FORM` — conferidos no código da UI, branch `forever`.

## 0.4.0 — 2026-10-21

- Painel de opções nativo (Opções > AddOns > CritRag): ativado, canal (Principal/Efeitos), dano mínimo (0–5000, passo 50), intervalo mínimo (0–1 s), liga/desliga por arma (arco/espada) e botões "Testar".
- `/critrag` sem argumento abre o painel; status passou para `/critrag status`.
- SavedVariables v2: novo `categories = { bow, sword }` (migração automática da v1).
- Não testado em jogo (beta encerrado). API do Settings conferida no código da UI da Blizzard, branch `forever` (1.60.1 build 70450).

### APIs novas

- `Settings.RegisterVerticalLayoutCategory` (retorna `category, layout`), `Settings.RegisterAddOnSetting`, `Settings.RegisterAddOnCategory`, `Settings.CreateCheckbox`, `Settings.CreateDropdown`, `Settings.CreateControlTextContainer`, `Settings.CreateSlider`, `Settings.CreateSliderOptions` (+ `:SetLabelFormatter`), `Settings.OpenToCategory`, `Settings.VarType`, `setting:SetValueChangedCallback`, `category:GetID`, `layout:AddInitializer`, `CreateSettingsListSectionHeaderInitializer`, `CreateSettingsButtonInitializer`, `MinimalSliderWithSteppersMixin.Label.Right`

## 0.3.0 — 2026-10-21

- Addon renomeado de CritSound para **CritRag** (evita conflito com o CritSound de Nexio): pasta, TOC, `/critrag`, SavedVariables `CritRagDB` (configurações do CritSoundDB não são migradas).
- Dano mínimo do crítico: `/critrag min <dano>` (padrão 0 = qualquer crítico). Usa o `amount` do `UNIT_COMBAT`.

## 0.2.0 — 2026-10-21

- `COMBAT_LOG_EVENT_UNFILTERED` confirmado bloqueado para addons no Forever 1.60.1. Detecção trocada para `UNIT_COMBAT` no alvo (`WOUND` + `CRITICAL`).
- Arma inferida pelo estado de ataque automático: Auto Shot ativo → arco (slot ranged); auto-attack corpo a corpo → espada (main-hand, senão off-hand).
- Limitação: `UNIT_COMBAT` não informa a fonte — críticos de outros jogadores ou do seu pet no seu alvo também tocam som.
- `/critsound` agora mostra o som da arma atual em vez do estado do combat log.

### APIs usadas (auditar a cada build da beta)

- Eventos: `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_EQUIPMENT_CHANGED`, `UNIT_COMBAT`, `START_AUTOREPEAT_SPELL`, `STOP_AUTOREPEAT_SPELL`, `PLAYER_ENTER_COMBAT`, `PLAYER_LEAVE_COMBAT`
- Funções: `GetInventoryItemID`, `C_Item.GetItemInfoInstant`, `PlaySoundFile`, `UnitCanAttack`, `GetTime`, `issecretvalue`, `CopyTable`
- Enums/constantes: `Enum.ItemClass.Weapon`, `Enum.ItemWeaponSubclass.{Bows,Sword1H,Sword2H}`, `INVSLOT_MAINHAND/OFFHAND/RANGED`

## 0.1.0 — 2026-10-21

- Primeira versão: som de crítico para **arco** e **espada** via `COMBAT_LOG_EVENT_UNFILTERED` (não funciona no Forever).
- Comandos `/critsound`, `on`, `off`, `test bow|sword`, `channel master|sfx`.
