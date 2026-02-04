---
trigger: always_on
---

# 📋 Regras Globais e Documentação: Projeto ABH (Handball Roblox)

Este documento contém as diretrizes mandatórias para qualquer alteração, criação ou manutenção de código no projeto ABH.

## 1. Regras Fundamentais
1. **Entendimento Prévio**: Sempre entenda como o projeto funciona antes de fazer alterações.
2. **Domínio**: O jogo é sobre Handball no Roblox (Luau).
3. **Análise de Dependências**: Entenda como os arquivos estão separados e as dependências entre sistemas antes de alterar.
4. **Clean Code**: Siga a organização atual (divisão por setores, documentação extensiva, comentários).
5. **Tipagem**: Use tipos (`type annotations`) em todos os novos módulos e funções.
6. **Nomenclatura**: Use `camelCase` para funções/variáveis e `UPPER_CASE` para constantes.
7. **Headers**: Todo módulo deve ter o header de documentação padrão (barra de demarcadores `=`).
8. **Memory Leaks**: Use obrigatoriamente `Janitor` ou `Maid` para gerenciar e limpar conexões/instâncias.
9. **Reutilização**: Sempre use utilitários compartilhados (`TeamUtils`, `SharedTypes`) em vez de reescrever lógica.
10. **Segurança**: Eventos de rede devem passar por validação rigorosa (AntiHack/Rate Limiting).
11. **Integridade**: Não edite arquivos sem entender suas dependências sistêmicas.
12. **Git**: Documente tudo em um git para ter updates historicos.
13. **Atualização**: Cada atualização coloque no github https://github.com/Stawyn/HandballRoblox.git

---

## 2. 🏗️ Arquitetura do Projeto

### Sistema de Carregamento (Loader)
O projeto utiliza um script **Loader** (`src/Loader/init.server.lua`) que:
- Distribui pastas filhas para seus serviços (ReplicatedStorage, ServerScriptService, etc.).
- Cria a estrutura física no Workspace: `Core/Data`, `Core/Balls`, `Core/GLT`.
- Gerencia o `StarterPlayer` (Scripts de Personagem e Jogador).
- Dispara o sinal `LoaderReady` ao finalizar.

### 📁 Estrutura de Arquivos e Responsabilidades

#### SERVER (ServerScriptService/Modules)
- **📂 Systems/**
    - `ABHBall.luau`: Física, posse, arremesso, Motor6D, Anti-Stuck, Anti-Void, Drag Force.
    - `NetworkServer.luau`: Processamento central de RemoteEvents (Throw, GK, Referee, Ball Management).
    - `GoalDetection.luau`: Tecnologia de Linha de Gol (GLT), registros de gols/assists e emojis.
    - `GameStatistics.luau`: Estatísticas, Webhooks Discord e DataStore.
    - `KeybindInit.luau`: Inicialização de inputs no servidor.
    - `Collisions.luau`: Grupos de colisão.
    - `Player.luau`: Lógica de servidor para o objeto Player.
    - `ReplaySystem.luau`: Gravação de replays.
- **📂 Implementation/**
    - `ABHLeague.luau`: Lógica de partida (Timer, Cartões, Pênaltis, Pausa, ForceField).
    - `ProfileStore.luau`: Persistência de dados.
    - `Timer.luau`: Sistema de cronometragem.
    - `PingModule.luau`: Monitoramento de latência.
    - `PlayerCharacter.luau`: Configuração do Rig/Personagem.
- **📂 Security/**
    - `AntiHack.luau`: Rate limiting e validação de pacotes.

#### CLIENT (ReplicatedStorage/Modules)
- **📂 Systems/**
    - `ABHBallClient.luau`: Lógica visual e previsão da bola no cliente.
    - `Stamina.luau`: Sprint, pulo, regeneração de energia.
    - `CardSystem.luau`: Interface de cartões e tempo de expulsão (120s).
    - `RefereeClient.luau`: Interface administrativa do árbitro.
    - `Topbar.luau`: Menu superior, BallCam, Stats.
    - `ScoreboardClient.luau`: Placar visual.
    - `SwitchHands.luau`: Alternância entre mão esquerda/direita.
- **📂 Implementation/**
    - `InputSystem.luau`: Contextos de input, mobile/PC, botões dinâmicos.
    - `ClientNetwork.luau`: Wrapper de comunicação.
    - `ThrowPower.luau`: Cálculos de força de arremesso.
    - `StaminaUI.luau` / `PowerUI.luau`: Feedback visual de status.
- **📂 ToolsController/**
    - Controladores de ferramentas: `SpawnTool`, `SetPieceTool`, `PenaltyTool`, `KeeperTool`.

#### SHARED (ReplicatedStorage/Utilities)
- `SharedTypes.luau`: Definições de tipos (ABHBallInstance, DirectionData, etc.).
- `TeamUtils.luau`: Verificações de time (isHomePlayer, isGoalkeeper, areOpponents).
- `Signal.luau` / `Janitor.luau` / `Maid.luau`: Utilitários de eventos e limpeza.
- `Utils.luau` / `Vector.luau` / `Math.luau`: Helpers matemáticos e gerais.
- `ABHAnimations.luau`: Dicionário de IDs de animação.

---

## 3. 🔄 Fluxo de Comunicação (Networking)

1. **Throw**: Cliente -> `ThrowEvent` -> `NetworkServer` -> `ABHBall:Throw()`.
2. **Defesa**: Cliente -> `GoalkeeperEvent` -> `NetworkServer` -> Ativa hitbox de defesa.
3. **Árbitro**: Cliente -> `RefereeEvent` -> `NetworkServer` -> `ABHLeague` (Pause/Goal).
4. **Updates**: Servidor -> `LeagueEvent` / `StatsUpdate` -> Cliente (UI/Sincronização).

---

## 4. ⚽ Conceitos de Jogo (Domínio)

- **Times**: `Home Team`, `Away Team`, `Officials`, `Lobby`.
- **Goleiros**: Identificados pelo prefixo "-" no time (ex: `-Home Goalkeeper`).
- **Estados da Bola**:
    - `CurrentPlayerOnBall`: Jogador com a posse.
    - `LastThrow`: Último a arremessar.
    - `LastLastThrow`: Assistência.
    - `RefereeImmunity`: Proteção contra roubo.
- **Estados da Partida**: `BeingPlayed`, `MatchPaused`, `Half` (1 e 2), `HomeScore/AwayScore`.
- **Cartões**: 
    - Amarelo (YC): Aviso visual. 2 YC = Vermelho.
    - Vermelho (RC): Expulsão por 120s para o Lobby.

---

## 5. 📝 Padrões de Código (Templates)

### Header de Módulo

--[[
    ================================================================================
    MÓDULO: NomeDoModulo
    ================================================================================
    Descrição: Explicação concisa da finalidade.
    Funcionalidades: - Lista de features.
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: NOME DO SETOR
--// ============================================================================

--- Descrição da função
-- @param parametro Tipo - Descrição
-- @return Tipo - Descrição
function MinhaFuncao(parametro: string): number
    -- implementação
end

## ⚠️ Cuidados Especiais
ABHBall e ABHLeague são interdependentes - Alterações em um afetam o outro
NetworkServer é crítico - Todos os eventos de rede passam por ele
Valide sempre no servidor - Nunca confie 100% no cliente
Use Janitor - Para evitar memory leaks em conexões
SharedTypes - Sempre use os tipos definidos para autocomplete e segurança
TeamUtils - Não reimplemente verificações de time, use TeamUtils
Webhook Discord - GameStatistics envia dados para Discord automaticamente