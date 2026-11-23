# ACS — Comunidade do Trabalho

RPG 2D de exploração, narrativa e simulação de vida comunitária ambientado em uma cidade brasileira de interior, desenvolvido em **Godot 4.4.x (GDScript tipado)**.

## Documentação do Projeto

- [Explanation.md](./docs/Explanation.md) — Visão geral, premissa narrativa e pilares de gameplay
- [GDD.md](./docs/GDD.md) — Especificação técnica inicial e critérios da Vertical Slice
- [GUIA_TECNICO_VERTICAL_SLICE.md](./docs/GUIA_TECNICO_VERTICAL_SLICE.md) — Arquitetura enxuta e roadmap faseado (M0–M6)
- `docs/visual_references/` — Referências visuais de direção de arte e UI

## Setup Local

1. Instale **Godot 4.4.1-stable (Standard / GDScript)**.
2. Abra `project.godot` no editor Godot 4.4.
3. **Protocolo OneDrive + Git:** feche o editor Godot antes de rodar `git pull`, `git merge` ou trocar de branch.

## Rodando os Testes (GUT Headless)

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## Estrutura Principal

- `scripts/core/` — Núcleo global (`EventBus`, `WorldState`, `SaveSystem`, etc.)
- `scenes/` — Cenas de boot, jogador, NPCs, mapas e UI
- `data/` — Recursos `.tres`, eventos, rotinas e diálogos `.dialogue`
- `tests/` — Suítes automatizadas (GUT)
- `docs/` e `art_source/` — Ignorados pelo importador do Godot via `.gdignore`
