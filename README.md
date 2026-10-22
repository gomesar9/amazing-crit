# AmazingCrit

Addon para **World of Warcraft: Forever** que toca um som quando o seu personagem acerta um crítico, com som diferente conforme a arma. Uso e limitações: [`AmazingCrit/README.md`](AmazingCrit/README.md).

## Estrutura

```
AmazingCrit/              addon (é esta pasta que vai para Interface/AddOns/)
  AmazingCrit.toc
  Config.lua          defaults, lista de armas e migração de SavedVariables
  Core.lua            detecção de crítico, classificação de armas, sons, slash
  Options.lua         painel em Opções > AddOns
  Locales/            enUS, ptBR
  Sounds/             .ogg tocados pelo addon
assets/sounds/        originais dos sons (.mp3)
tests/run.lua         testes offline com stubs da API do WoW
docs/UI_PLAN.md       plano do painel de opções
CLAUDE.md             decisões técnicas e regras da API do Forever
```

## Desenvolvimento

```sh
lua tests/run.lua        # testes offline (Lua 5.4)
```

Para instalar, copie (ou crie um symlink de) `AmazingCrit/` para `<WoW>/_classic_beta_/Interface/AddOns/`.

### Sons

Originais em `assets/sounds/`; o addon usa `.ogg` em `AmazingCrit/Sounds/`:

| Original | Gerado |
|---|---|
| `bow-crit.mp3` | `bow.ogg` |
| `sword-crit.mp3` | `sword.ogg`, `generic.ogg` (provisório) |

```sh
ffmpeg -i assets/sounds/bow-crit.mp3 -c:a libvorbis -q:a 5 AmazingCrit/Sounds/bow.ogg
```

Arquivo de som novo ou trocado exige reiniciar o cliente (`/reload` pode não bastar).
