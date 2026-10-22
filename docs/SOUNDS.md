# Mapeamento de sons do AmazingCrit

Tabela de cada gatilho de som, nos dois modos, com o arquivo usado hoje e o nome padronizado sugerido para o som definitivo.

- Arquivos ficam em `AmazingCrit/Sounds/` (no jogo: `Interface/AddOns/AmazingCrit/Sounds/`). Formato `.ogg`; originais em `assets/sounds/`.
- **`*`** = hoje toca `generic.ogg` porque **falta o som específico**.
- **Chave** = nome usado no código (`sounds` em `Config.lua`) e no comando `/amazingcrit test <chave>`.
- Padrão de nome: `<modo>_<chave>.ogg`, tudo minúsculo, `_` como separador.

## Modo "Por fonte (preciso)"

### Dano crítico no seu alvo (pela escola do dano)

| Gatilho | Chave | Arquivo atual | Arquivo sugerido |
|---|---|---|---|
| Dano físico (ataque comum ou habilidade física) | `physical` | `generic.ogg` * | `source_physical.ogg` |
| Dano sagrado | `holy` | `generic.ogg` * | `source_holy.ogg` |
| Dano de fogo | `fire` | `generic.ogg` * | `source_fire.ogg` |
| Dano de natureza | `nature` | `generic.ogg` * | `source_nature.ogg` |
| Dano de gelo | `frost` | `generic.ogg` * | `source_frost.ogg` |
| Dano de sombra | `shadow` | `generic.ogg` * | `source_shadow.ogg` |
| Dano arcano | `arcane` | `generic.ogg` * | `source_arcane.ogg` |

### Cura crítica

| Gatilho | Chave | Arquivo atual | Arquivo sugerido |
|---|---|---|---|
| Cura crítica em você | `heal_player` | `generic.ogg` * | `source_heal_player.ogg` |
| Cura crítica no seu pet | `heal_pet` | `generic.ogg` * | `source_heal_pet.ogg` |
| Cura crítica no seu alvo (amigável) | `heal_target` | `generic.ogg` * | `source_heal_target.ogg` |

### Dano recebido por você

| Gatilho | Chave | Arquivo atual | Arquivo sugerido |
|---|---|---|---|
| Crítico recebido | `taken_crit` | `generic.ogg` * | `source_taken_crit.ogg` |
| Golpe esmagador recebido | `taken_crushing` | `generic.ogg` * | `source_taken_crushing.ogg` |

## Modo "Por arma (solo)"

### Corpo a corpo (ataque automático)

| Gatilho | Chave | Arquivo atual | Arquivo sugerido |
|---|---|---|---|
| Espada (1M/2M) | `sword` | `sword.ogg` | `weapon_sword.ogg` (renomear) |
| Machado (1M/2M) | `axe` | `generic.ogg` * | `weapon_axe.ogg` |
| Maça (1M/2M) | `mace` | `generic.ogg` * | `weapon_mace.ogg` |
| Adaga | `dagger` | `generic.ogg` * | `weapon_dagger.ogg` |
| Arma de punho | `fist` | `generic.ogg` * | `weapon_fist.ogg` |
| Arma de haste | `polearm` | `generic.ogg` * | `weapon_polearm.ogg` |
| Cajado | `staff` | `generic.ogg` * | `weapon_staff.ogg` |

### À distância (tiro automático)

| Gatilho | Chave | Arquivo atual | Arquivo sugerido |
|---|---|---|---|
| Arco | `bow` | `bow.ogg` | `weapon_bow.ogg` (renomear) |
| Arma de fogo | `gun` | `generic.ogg` * | `weapon_gun.ogg` |
| Besta | `crossbow` | `generic.ogg` * | `weapon_crossbow.ogg` |
| Varinha | `wand` | `generic.ogg` * | `weapon_wand.ogg` |
| Arremesso | `thrown` | `generic.ogg` * | `weapon_thrown.ogg` |

## Fallback

| Gatilho | Chave | Arquivo atual | Arquivo sugerido |
|---|---|---|---|
| Qualquer chave sem som próprio | `generic` | `generic.ogg` (cópia provisória do som de espada) | `generic.ogg` |

## Resumo

- 24 gatilhos: 12 no modo por fonte, 12 no modo por arma.
- 2 com som próprio (`sword`, `bow`); **22 faltando** (`*`).
- `sword.ogg` e `bow.ogg` funcionam como estão; "(renomear)" só indica o nome no padrão, se quiser uniformizar. Atenção: a tabela `sounds` fica salva na configuração do jogador (`AmazingCritDB`), então renomear um arquivo de chave **já existente** exige uma migração em `Config.lua`; chaves novas não precisam.

## Como adicionar um som

1. Converta o arquivo para `.ogg` com o nome sugerido, por exemplo:
   `ffmpeg -i assets/sounds/fire.mp3 -c:a libvorbis -q:a 5 AmazingCrit/Sounds/source_fire.ogg`
2. Ligue a chave ao arquivo em `ns.defaults.sounds` (`AmazingCrit/Config.lua`), por exemplo `fire = "source_fire.ogg"`. Quem já tem configuração salva recebe a chave nova automaticamente.
3. Feche e reabra o jogo (arquivo de som novo não é carregado com `/reload`).
4. Confira com `/amazingcrit test <chave>`.
