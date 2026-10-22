# CritRag

Toca um som quando **o seu personagem** acerta um crítico, conforme a arma usada.

| Arma | Quando toca | Som |
|---|---|---|
| Espada (1M/2M) | auto-attack corpo a corpo ligado | `Sounds/sword.ogg` |
| Machado, maça (1M/2M), adaga, arma de punho, arma de haste, cajado | auto-attack corpo a corpo ligado | `Sounds/generic.ogg` |
| Arco | tiro automático (Auto Shot) ligado | `Sounds/bow.ogg` |
| Arma de fogo, besta, varinha, arremesso | tiro automático ligado | `Sounds/generic.ogg` |

Cada tipo de arma pode ser desligado no painel. Vara de pesca e soco (sem arma) não tocam. Druida em qualquer forma (urso, gato etc.) não toca.

## Instalação

Copie a pasta `CritRag` para `World of Warcraft/_classic_beta_/Interface/AddOns/`
(após o lançamento, confirmar a pasta do Forever).

## Opções

Painel em **Opções > AddOns > CritRag** (ou `/critrag`):

- **Ativado**
- **Canal de áudio** — Principal ou Efeitos (o volume do canal controla o volume do som)
- **Dano mínimo** — 0 a 5000; passos de 5 até 50, de 10 até 100, de 50 até 1000 e de 100 até 5000
- **Intervalo mínimo** — tempo mínimo entre dois sons (0 a 1 s)
- **Armas** — liga/desliga para cada tipo de arma
- **Sons** — botões "Testar" para arco, espada e genérico

O botão "Padrões" do painel restaura tudo.

## Comandos

- `/critrag` — abre o painel de opções
- `/critrag status` — status e ajuda
- `/critrag on` / `off`
- `/critrag test <arma>` — toca o som da arma (`sword`, `axe`, `mace`, `dagger`, `fist`, `polearm`, `staff`, `bow`, `gun`, `crossbow`, `wand`, `thrown`) ou `generic`
- `/critrag min 300` — só toca em críticos com dano ≥ 300 (`min 0` = qualquer crítico; padrão 0). Aceita qualquer valor; o slider mostra o passo mais próximo
- `/critrag channel master` / `sfx` — canal de áudio (volume segue o canal)

## Limitações

- O Forever bloqueia `COMBAT_LOG_EVENT_UNFILTERED` para addons. O CritRag usa `UNIT_COMBAT` no seu **alvo**, que não informa quem causou o dano:
  - em grupo, críticos de outros jogadores no seu alvo também tocam som;
  - críticos do seu pet também tocam som;
  - a arma é deduzida pelo ataque automático ativo (Auto Shot → arco; corpo a corpo → espada da main-hand, senão off-hand).
- Use `/critrag min <dano>` para reduzir esses falsos positivos: críticos pequenos (pet, outros jogadores) deixam de tocar.
- Arremesso e o "Shoot" de guerreiro/ladino com arco, arma de fogo ou besta podem não ser tiro automático no Forever (no vanilla não eram); nesse caso não tocam.
- Críticos de habilidades só tocam se o ataque automático correspondente estiver ligado.
- Dentro de encontros de raid os dados podem vir como *secret values*; nesse caso o som não toca.
- Ao trocar/adicionar arquivos de som, **feche e reabra o jogo** — `/reload` pode não bastar.

## Trocar os sons

Os arquivos ficam em `Interface/AddOns/CritRag/Sounds/`: `bow.ogg`, `sword.ogg` e `generic.ogg` (usado por todas as outras armas). Para trocar, substitua o arquivo mantendo o nome e **reinicie o jogo**.

## Depuração

`/console scriptErrors 1`, BugSack + BugGrabber.
