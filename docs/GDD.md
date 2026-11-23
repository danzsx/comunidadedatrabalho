# ESPECIFICAÇÃO TÉCNICA INICIAL — PROJETO ACS

**Versão:** 1.0  
**Etapa:** Pré-produção técnica  
**Engine recomendada:** Godot 4  
**Linguagem:** GDScript  
**Arquitetura:** Modular, orientada a dados e baseada em eventos

---

## 1. Objetivo técnico

Desenvolver um RPG 2D de exploração e simulação de vida comunitária, ambientado em uma cidade brasileira de interior.

O projeto deverá permitir:

- Exploração de ambientes internos e externos.
- Interação com personagens e famílias.
- Progressão narrativa baseada em acontecimentos e escolhas.
- Simulação de uma cidade dinâmica.
- Atividades profissionais relacionadas ao trabalho de ACS.
- Projetos pessoais e comunitários contextualizados.
- Enigmas e desafios simbólicos.
- Evolução da trajetória profissional e pessoal de Alex.
- Salvamento e carregamento persistente do mundo.

A arquitetura deverá permitir expansão sem exigir reescrita dos sistemas fundamentais.

## 2. Tecnologias e padrões

### 2.1 Engine

Godot 4.x.

### 2.2 Linguagem

GDScript tipado sempre que possível.

### 2.3 Organização

- Cenas independentes para entidades e ambientes.
- Recursos e arquivos de dados para conteúdo.
- Sistemas responsáveis por regras específicas.
- Sinais para comunicação entre sistemas.
- Gerenciadores globais somente para estados realmente globais.
- Separação entre lógica de jogo, dados e interface.

### 2.4 Diretrizes

Evitar:

- Scripts monolíticos.
- Dependência excessiva de Autoloads.
- Informações de NPCs espalhadas pelo código.
- Missões implementadas diretamente na interface.
- Sistemas que dependam de referências rígidas entre cenas.
- Simulação desnecessária a cada frame.

---

## 3. Arquitetura geral

Organizar o projeto em módulos:

### CORE
Responsável pelo funcionamento global.

- GameManager
- TimeManager
- CalendarManager
- SaveManager
- EventManager
- SceneManager

### WORLD
Responsável pelo mundo explorável.

- WorldManager
- RegionManager
- MapManager
- InteriorManager
- EnvironmentManager
- WeatherManager

### CHARACTERS
Responsável pelos personagens.

- PlayerController
- NPCController
- CharacterManager
- FamilyManager
- RelationshipManager
- RoutineManager

### SYSTEMS
Responsável pelas mecânicas gerais.

- DialogueSystem
- QuestSystem
- InventorySystem
- InteractionSystem
- CraftingSystem
- GardeningSystem
- ExplorationSystem
- PuzzleSystem
- ProgressionSystem

### PROFESSIONAL
Responsável pelas atividades relacionadas ao trabalho.

- FieldVisitSystem
- HouseholdRecordSystem
- WorkScheduleSystem
- CommunityProjectSystem
- ProfessionalProgressionSystem

### NARRATIVE
Responsável pela narrativa.

- ChapterManager
- StoryEventManager
- CharacterStoryManager
- DreamSystem
- LegendSystem
- EndingManager

### PLAYER LIFE
Responsável pela vida pessoal de Alex.

- PersonalProjectSystem
- StudySystem
- HomeSystem
- PersonalProgressionSystem

### DATA
Dados externos ao código.

- Characters
- Families
- Items
- Recipes
- Events
- Quests
- Dialogues
- Locations
- NPC Routines
- Projects

### UI
Interfaces.

- HUD
- DialogueUI
- NotebookUI
- InventoryUI
- MapUI
- CalendarUI
- QuestUI
- CharacterProfileUI
- ProjectUI

---

## 4. Sistema de tempo

O tempo será dividido em quatro períodos:

1. Manhã
2. Tarde
3. Noite
4. Madrugada

As ações poderão consumir períodos inteiros ou unidades de tempo abstratas, conforme a mecânica.

O sistema deverá controlar:

- Dia atual.
- Semana.
- Mês.
- Estação.
- Período atual.
- Eventos agendados.
- Rotinas dos NPCs.
- Condições de disponibilidade de locais e personagens.

O avanço do tempo deverá disparar eventos e atualizações de rotina.

O jogador não deverá ser penalizado por pequenas variações de horário. A gestão do tempo deve gerar escolhas, não uma rotina excessivamente restritiva.

---

## 5. Sistema de personagens e famílias

Cada personagem deverá possuir dados independentes de sua representação visual.

### Dados básicos

- ID único.
- Nome.
- Idade.
- Personalidade.
- Ocupação.
- Residência.
- Família.
- Rotina.
- Interesses.
- Conhecimentos.
- Relações com outros personagens.
- Estado narrativo.
- Eventos associados.

### Relações

Não utilizar apenas um medidor genérico de amizade.

Considerar dimensões independentes:

- Confiança.
- Afinidade.
- Familiaridade.
- Cooperação.

As relações deverão influenciar diálogos, oportunidades, atividades e acontecimentos.

### Famílias

Cada família deverá possuir:

- Integrantes.
- Histórico.
- Residência.
- Condições e acontecimentos relevantes.
- Relações internas.
- Eventos futuros possíveis.

O sistema deverá permitir nascimentos, envelhecimento, mudanças de residência, separações, casamentos, falecimentos e alterações na composição familiar.

Esses eventos deverão ocorrer por regras e condições narrativas, não exclusivamente por intervenção de Alex.

---

## 6. Simulação do mundo

A cidade deverá funcionar por eventos e atualizações periódicas.

Não executar a simulação completa de todos os personagens a cada frame.

Exemplo de funcionamento:

1. O jogador encerra o dia.
2. O TimeManager solicita atualização do mundo.
3. O EventManager verifica eventos pendentes.
4. O RoutineManager atualiza rotinas e disponibilidades.
5. O FamilyManager processa acontecimentos familiares.
6. O RelationshipManager atualiza relações quando houver condições.
7. Os novos estados são persistidos.

Os eventos devem possuir condições de ativação, consequências e possibilidade de dependência de outros eventos.

O sistema deverá suportar acontecimentos que ocorram sem a presença do jogador.

---

## 7. Sistema de trabalho do ACS

O trabalho deverá ser uma das principais formas de interação com a cidade.

Cada visita poderá envolver:

1. Preparação.
2. Deslocamento.
3. Observação.
4. Conversa.
5. Identificação de informações relevantes.
6. Registro no caderno.
7. Encaminhamento ou articulação, quando apropriado.
8. Acompanhamento posterior.

As visitas não deverão funcionar como tarefas repetitivas de coleta de recompensas.

O sistema deverá considerar:

- Disponibilidade dos moradores.
- Histórico da família.
- Relação com Alex.
- Informações já descobertas.
- Situações pendentes.
- Consequências de abordagens anteriores.

As atividades devem respeitar o papel profissional do ACS. O jogo não deverá transformar Alex em médico ou atribuir a ele diagnósticos e procedimentos que não correspondem à função.

---

## 8. Projetos pessoais e comunitários

Os projetos secundários deverão surgir das relações estabelecidas no mundo.

Exemplos:

- Recuperação de um jardim com uma moradora.
- Manutenção da bicicleta com a ajuda de um mecânico.
- Recuperação de uma praça.
- Organização de uma horta comunitária.
- Recuperação de um espaço de convivência.

Cada projeto deverá possuir:

- Condições de desbloqueio.
- Personagens envolvidos.
- Etapas.
- Recursos necessários.
- Conhecimentos necessários.
- Mudanças produzidas no mundo.
- Possíveis consequências narrativas.

O sistema de crafting deverá ser contextualizado. Não criar atividades genéricas apenas para ampliar a quantidade de receitas.

---

## 9. Sistema de enigmas e desafios simbólicos

Criar um sistema independente do combate tradicional.

Um desafio poderá conter:

- Ambiente próprio.
- Pistas.
- Objetos interativos.
- Condições de progressão.
- Escolhas.
- Estados intermediários.
- Conclusão.
- Consequências narrativas.

Os desafios poderão ocorrer em sonhos, locais misteriosos ou situações especiais.

A resolução deverá priorizar observação, exploração, interpretação e interação.

---

## 10. Sistema narrativo

A narrativa deverá ser organizada por capítulos, eventos e histórias individuais.

Cada evento poderá possuir:

- Identificador.
- Condições de ativação.
- Pré-requisitos.
- Personagens envolvidos.
- Local.
- Diálogos.
- Ações disponíveis.
- Alterações de estado.
- Próximos eventos possíveis.

A trajetória profissional de Alex deverá ser controlada por variáveis e decisões persistentes.

O sistema de finais deverá consultar o histórico e as escolhas do jogador, sem impor um único destino profissional.

---

## 11. Sistema de salvamento

O salvamento deverá persistir, no mínimo:

- Dia, período e calendário.
- Posição e localização de Alex.
- Inventário.
- Recursos.
- Projetos pessoais e comunitários.
- Relações.
- Estado dos personagens.
- Composição das famílias.
- Eventos concluídos e pendentes.
- Progresso dos capítulos.
- Regiões desbloqueadas.
- Variáveis da trajetória profissional.
- Estado dos enigmas.
- Alterações permanentes no mundo.

Adotar IDs estáveis para personagens, famílias, itens, eventos e projetos.

Não depender da ordem de carregamento das cenas para reconstruir o estado do jogo.

---

## 12. Estrutura de diretórios sugerida

```text
ACS_GAME/
├── assets/
│   ├── characters/
│   ├── environments/
│   ├── tilesets/
│   ├── objects/
│   ├── audio/
│   └── fonts/
├── scenes/
│   ├── player/
│   ├── npcs/
│   ├── maps/
│   ├── interiors/
│   ├── ui/
│   └── events/
├── scripts/
│   ├── core/
│   ├── world/
│   ├── characters/
│   ├── systems/
│   ├── professional/
│   ├── narrative/
│   └── player_life/
├── data/
│   ├── characters/
│   ├── families/
│   ├── dialogues/
│   ├── events/
│   ├── quests/
│   ├── items/
│   └── projects/
├── resources/
├── shaders/
└── tests/
```

---

## 13. Escopo da primeira versão jogável

A primeira versão deverá ser uma vertical slice, não uma versão reduzida de todos os sistemas.

### Conteúdo

- Uma UBS.
- Uma praça.
- Um pequeno bairro.
- Três residências.
- Casa de Alex.
- Hortência.
- Seis a oito moradores.
- Três famílias.
- Uma semana de jogo.

### Funcionalidades obrigatórias

1. Movimentação e colisões.
2. Câmera top-down.
3. Transições entre ambientes.
4. Interação com NPCs.
5. Sistema de diálogos.
6. Tempo por períodos.
7. Rotinas básicas de NPCs.
8. Caderno de campo.
9. Uma visita domiciliar completa.
10. Uma situação narrativa com consequências.
11. Um projeto pessoal contextualizado.
12. Um evento independente de Alex.
13. Salvamento e carregamento.

### Critério de aprovação

A vertical slice será considerada funcional quando o jogador conseguir experimentar um ciclo completo:

- Conhecer a UBS e Hortência.
- Receber uma atividade.
- Conhecer moradores.
- Realizar uma visita.
- Descobrir uma situação.
- Registrar informações.
- Desenvolver uma relação.
- Desbloquear um projeto pessoal.
- Perceber uma mudança no mundo.
- Avançar o calendário e carregar o jogo sem perder o estado.

---

## 14. Ordem de implementação

### Fase 1 — Fundação
Movimento, câmera, colisões, mapas e transições.

### Fase 2 — Interação
NPCs, diálogos, objetos e sistema de interação.

### Fase 3 — Tempo e mundo
Calendário, períodos, rotinas e eventos independentes.

### Fase 4 — Trabalho
Visitas, caderno de campo, registros e situações familiares.

### Fase 5 — Progressão
Inventário, projetos, coleta e crafting contextualizado.

### Fase 6 — Narrativa
Capítulos, relações, histórias individuais e escolhas.

### Fase 7 — Persistência
Salvamento completo, carregamento e testes de consistência.

### Fase 8 — Expansão
Novos bairros, famílias, faculdade, sonhos e desafios simbólicos.

---

## 15. Princípios técnicos inegociáveis

1. Sistemas independentes e reutilizáveis.
2. Conteúdo separado da lógica de programação.
3. Estado do mundo persistente.
4. Simulação baseada em eventos, não em processamento contínuo desnecessário.
5. Personagens identificados por IDs estáveis.
6. Nenhuma mecânica secundária sem justificativa no universo.
7. Nenhuma progressão profissional baseada apenas na quantidade de visitas.
8. O mundo deve continuar existindo independentemente da presença de Alex.
9. A narrativa deve reagir às escolhas sem exigir ramificações excessivamente complexas.
10. O protótipo deverá ser testável antes da expansão do conteúdo.

**Objetivo final:** construir uma base técnica pequena, consistente e expansível, capaz de sustentar uma cidade viva e uma narrativa centrada nas relações humanas.