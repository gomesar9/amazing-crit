# CritRag

Toca um som em críticos. Dois modos, trocados no painel:

### Por fonte (preciso) — padrão

Usa só o que o jogo informa com certeza. **Não sabe quem causou o crítico**: críticos de outros jogadores e de pets também tocam.

| Fonte | Quando toca |
|---|---|
| Dano no alvo: Físico, Sagrado, Fogo, Natureza, Gelo, Sombra, Arcano | dano crítico no seu alvo hostil, pela escola do dano |
| Cura em você / no seu pet / no seu alvo | cura crítica recebida (alvo amigável) |
| Crítico recebido / Golpe esmagador recebido | dano crítico ou esmagador em você |

Ataque comum e habilidade física são indistinguíveis (ambos "Físico"). Cada fonte terá som próprio; por enquanto todas usam `Sounds/generic.ogg`.

### Por arma (solo)

Crítico no seu alvo enquanto você está em ataque automático, com som pela arma equipada. A arma é deduzida pelo ataque automático, então só é confiável **jogando sozinho e sem pet**.

| Arma | Quando toca | Som |
|---|---|---|
| Espada (1M/2M) | auto-attack corpo a corpo ligado | `Sounds/sword.ogg` |
| Machado, maça (1M/2M), adaga, arma de punho, arma de haste, cajado | auto-attack corpo a corpo ligado | `Sounds/generic.ogg` |
| Arco | tiro automático (Auto Shot) ligado | `Sounds/bow.ogg` |
| Arma de fogo, besta, varinha, arremesso | tiro automático ligado | `Sounds/generic.ogg` |

Vara de pesca e soco (sem arma) não tocam. Druida em qualquer forma (urso, gato etc.) não toca.

## Instalação

Copie a pasta `CritRag` para `World of Warcraft/_classic_beta_/Interface/AddOns/`
(após o lançamento, confirmar a pasta do Forever).

## Opções

Painel em **Opções > AddOns > CritRag** (ou `/critrag`):

- **Ativado**
- **Modo** — Por fonte (preciso) ou Por arma (solo)
- **Canal de áudio** — Principal ou Efeitos (o volume do canal controla o volume do som)
- **Valor mínimo** — dano ou cura; 0 a 5000; passos de 5 até 50, de 10 até 100, de 50 até 1000 e de 100 até 5000
- **Intervalo mínimo** — tempo mínimo entre dois sons (0 a 1 s)
- **Fontes** — liga/desliga por fonte (ativo no modo por fonte)
- **Armas** — liga/desliga por tipo de arma (ativo no modo por arma)
- **Sons** — botões "Testar" para arco, espada e genérico

O botão "Padrões" do painel restaura tudo.

## Comandos

- `/critrag` — abre o painel de opções
- `/critrag status` — status e ajuda
- `/critrag on` / `off`
- `/critrag mode source` / `weapon` — troca o modo
- `/critrag test <som>` — toca um som: fonte (`physical`, `holy`, `fire`, `nature`, `frost`, `shadow`, `arcane`, `heal_player`, `heal_pet`, `heal_target`, `taken_crit`, `taken_crushing`), arma (`sword`, `axe`, `mace`, `dagger`, `fist`, `polearm`, `staff`, `bow`, `gun`, `crossbow`, `wand`, `thrown`) ou `generic`
- `/critrag min 300` — só toca em críticos (dano ou cura) ≥ 300 (`min 0` = qualquer crítico; padrão 0). Aceita qualquer valor; o slider mostra o passo mais próximo
- `/critrag channel master` / `sfx` — canal de áudio (volume segue o canal)

## Limitações

- O Forever bloqueia `COMBAT_LOG_EVENT_UNFILTERED` para addons. O CritRag usa `UNIT_COMBAT`, que informa quem recebeu o dano/cura, o tipo, o crítico, o valor e a escola — **mas não quem causou**.
- Modo por fonte: críticos de outros jogadores e pets no seu alvo, e curas críticas de outros healers em você, também tocam. Use o **valor mínimo** para filtrar críticos pequenos.
- Modo por arma: em grupo ou com pet, críticos de terceiros no seu alvo tocam o som da sua arma. Arremesso e o "Shoot" de guerreiro/ladino com arco, arma de fogo ou besta podem não ser tiro automático no Forever (no vanilla não eram); nesse caso não tocam.
- Dentro de encontros de raid os dados podem vir como *secret values*; nesse caso o som não toca.
- Ao trocar/adicionar arquivos de som, **feche e reabra o jogo** — `/reload` pode não bastar.

## Trocar os sons

Os arquivos ficam em `Interface/AddOns/CritRag/Sounds/`: `bow.ogg`, `sword.ogg` e `generic.ogg` (usado por todas as fontes e armas sem som próprio). Para trocar, substitua o arquivo mantendo o nome e **reinicie o jogo**.

## Depuração

`/console scriptErrors 1`, BugSack + BugGrabber.
