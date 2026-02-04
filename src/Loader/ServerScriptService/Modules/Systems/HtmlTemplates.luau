--[[
    ================================================================================
    MÓDULO: HtmlTemplates
    ================================================================================
    Descrição: Contém templates HTML/CSS para geração de imagens de estatísticas.
    Autor: Sistema ABH
    ================================================================================
]]

local HtmlTemplates = {}

local CSS = [[
<style>
    @import url('https://fonts.googleapis.com/css2?family=Montserrat:wght@400;700&family=Roboto+Mono:wght@400;700&display=swap');

    :root {
        --bg-color: #0d0e12;
        --panel-color: #16181d;
        --border-color: #2a2d35;
        --text-main: #ffffff;
        --text-dim: #a0a0a0;
        --accent-blue: #3498db;
        --accent-green: #2ecc71;
        --accent-red: #e74c3c;
        --accent-purple: #9b59b6;
        --accent-gold: #f1c40f;
        
        --cat-ataque: #1e3a5f;
        --cat-tecnico: #1e5f3a;
        --cat-geral: #5f1e1e;
        --cat-defesa: #4a1e5f;
    }

    body {
        font-family: 'Montserrat', sans-serif;
        background-color: var(--bg-color);
        color: var(--text-main);
        margin: 0;
        padding: 20px;
        width: 1100px;
        min-height: 600px; 
        display: flex;
        flex-direction: column;
        align-items: center;
    }

    .stats-container {
        width: 100%;
        background-color: var(--panel-color);
        border-radius: 12px;
        overflow: hidden;
        box-shadow: 0 10px 30px rgba(0,0,0,0.5);
        border: 1px solid var(--border-color);
    }

    .header-main {
        padding: 20px 30px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        border-bottom: 2px solid var(--border-color);
        background: linear-gradient(90deg, #16181d 0%, #1f2229 100%);
    }

    .match-info {
        display: flex;
        flex-direction: column;
    }

    .match-title {
        font-size: 24px;
        font-weight: 700;
        letter-spacing: 1px;
        text-transform: uppercase;
    }

    .match-id {
        font-family: 'Roboto Mono', monospace;
        font-size: 12px;
        color: var(--text-dim);
        margin-top: 4px;
    }

    .scoreboard {
        display: flex;
        align-items: center;
        gap: 20px;
        font-size: 32px;
        font-weight: 700;
    }

    .team { text-transform: uppercase; }
    .team.home { color: var(--accent-blue); }
    .team.away { color: var(--accent-red); }
    .score { 
        background: #2a2d35;
        padding: 5px 15px;
        border-radius: 6px;
        min-width: 80px;
        text-align: center;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        font-size: 12px;
    }

    /* Categorized Headers */
    .cat-header {
        text-transform: uppercase;
        font-weight: 700;
        padding: 8px 0;
        text-align: center;
        letter-spacing: 2px;
        font-size: 10px;
    }

    .cat-ataque { background-color: var(--cat-ataque); color: #8ecae6; }
    .cat-tecnico { background-color: var(--cat-tecnico); color: #b7e4c7; }
    .cat-geral { background-color: var(--cat-geral); color: #ffb3b3; }
    .cat-defesa { background-color: var(--cat-defesa); color: #e0b1cb; }

    th {
        background-color: #1f2229;
        color: var(--text-dim);
        padding: 12px 6px;
        text-align: center;
        font-weight: 700;
        border-bottom: 2px solid var(--border-color);
        border-right: 1px solid rgba(255,255,255,0.05);
    }

    th:first-child { text-align: left; padding-left: 20px; }
    th.mvp-col { color: var(--accent-gold); }

    td {
        padding: 14px 6px;
        text-align: center;
        border-bottom: 1px solid var(--border-color);
        font-family: 'Roboto Mono', monospace;
        font-size: 13px;
    }

    tr:nth-child(even) { background-color: rgba(255,255,255,0.02); }
    tr:hover { background-color: rgba(255,255,255,0.05); }

    .player-name {
        text-align: left;
        font-family: 'Montserrat', sans-serif;
        font-weight: 700;
        padding-left: 20px;
        color: #eee;
    }

    .mvp-star { color: var(--accent-gold); font-size: 18px; }
    
    .stat-highlight { font-weight: 700; color: var(--text-main); }
    .stat-dim { color: var(--text-dim); }

    .footer-info {
        padding: 15px 30px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-size: 10px;
        color: var(--text-dim);
        text-transform: uppercase;
        letter-spacing: 1px;
    }

    .team-section-title {
        padding: 10px 20px;
        background: #1a1c22;
        font-size: 14px;
        font-weight: 700;
        border-bottom: 1px solid var(--border-color);
        display: flex;
        align-items: center;
        gap: 10px;
    }
    .team-section-title::before {
        content: '';
        display: inline-block;
        width: 4px;
        height: 16px;
        background: var(--accent-blue);
    }
    .away-section::before { background: var(--accent-red); }
</style>
]]

function HtmlTemplates.GetTemplate()
    return [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=1140">
    ]] .. CSS .. [[
</head>
<body>

    <div class="stats-container">
        <div class="header-main">
            <div class="match-info">
                <div class="match-title">ABH Professional League</div>
                <div class="match-id">MATCH TIME: {{MATCH_TIME}}</div>
            </div>
            <div class="scoreboard">
                <span class="team home">{{HOME_NAME}}</span>
                <span class="score">{{HOME_SCORE}} - {{AWAY_SCORE}}</span>
                <span class="team away">{{AWAY_NAME}}</span>
            </div>
        </div>

        <div class="team-section-title">HOME TEAM STATISTICS</div>
        <table>
            <thead>
                <tr>
                    <th rowspan="2" style="width: 180px;">JOGADOR</th>
                    <th rowspan="2" class="mvp-col">MVP</th>
                    <th colspan="5" class="cat-header cat-ataque">ATAQUE</th>
                    <th colspan="2" class="cat-header cat-tecnico">TECNICO</th>
                    <th colspan="2" class="cat-header cat-geral">GERAL</th>
                    <th colspan="4" class="cat-header cat-defesa">DEFESA</th>
                </tr>
                <tr>
                    <th>GOLS</th>
                    <th>ASSIST</th>
                    <th>SOG</th>
                    <th>CA</th>
                    <th>EF%</th>
                    <th>PASSES</th>
                    <th>POSSE</th>
                    <th>STL</th>
                    <th>ERR</th>
                    <th>DEF</th>
                    <th>GS</th>
                    <th>EF%</th>
                    <th>RTG</th>
                </tr>
            </thead>
            <tbody>
                {{HOME_ROWS}}
            </tbody>
        </table>

        <div class="team-section-title away-section">AWAY TEAM STATISTICS</div>
        <table>
            <thead>
                <tr>
                    <th rowspan="2" style="width: 180px;">JOGADOR</th>
                    <th rowspan="2" class="mvp-col">MVP</th>
                    <th colspan="5" class="cat-header cat-ataque">ATAQUE</th>
                    <th colspan="2" class="cat-header cat-tecnico">TECNICO</th>
                    <th colspan="2" class="cat-header cat-geral">GERAL</th>
                    <th colspan="4" class="cat-header cat-defesa">DEFESA</th>
                </tr>
                <tr>
                    <th>GOLS</th>
                    <th>ASSIST</th>
                    <th>SOG</th>
                    <th>CA</th>
                    <th>EF%</th>
                    <th>PASSES</th>
                    <th>POSSE</th>
                    <th>STL</th>
                    <th>ERR</th>
                    <th>DEF</th>
                    <th>GS</th>
                    <th>EF%</th>
                    <th>RTG</th>
                </tr>
            </thead>
            <tbody>
                {{AWAY_ROWS}}
            </tbody>
        </table>

        <div class="footer-info">
            <span>Server: {{SERVER_ID}}</span>
            <span>Match ID: {{MATCH_ID}}</span>
            <span>ABH System v3.0</span>
        </div>
    </div>

</body>
</html>
]]
end

function HtmlTemplates.GenerateRow(stats, isMvp)
    if not stats then return "" end

    local name = stats.Name or "Unknown"
    local rating = string.format("%.1f", stats.Rating or 6.0)
    
    -- MVP Star
    local mvpCell = isMvp and '<td class="mvp-star">★</td>' or '<td></td>'

    -- Stats Mapping
    local goals = stats.Goals or 0
    local assists = stats.Assists or 0
    local sog = stats.SOG or 0
    local ca = stats.FastBreakGoals or 0
    
    local shots = stats.Shots or 0 -- For Efic Calc if needed, but we have EficPct
    local efPct = (stats.EficPct or 0) .. "%"
    
    local passes = stats.PassesCompleted or 0
    
    -- Possession calculation (assuming stats.PossessionTime is in seconds)
    -- Formatting to string with implicit precision
    local possession = string.format("%.0fs", stats.PossessionTime or 0)
    
    local steals = stats.Steals or 0
    local err = stats.Turnovers or 0
    
    local saves = stats.Saves or 0
    local gs = stats.GoalsConceded or 0
    local defPct = (stats.DefPct or 0) .. "%"

    -- Truncar nome
    if #name > 14 then name = string.sub(name, 1, 12)..".." end

    return string.format([[
    <tr>
        <td class="player-name">%s</td>
        %s
        <td class="stat-highlight">%d</td>
        <td>%d</td>
        <td>%d</td>
        <td>%d</td>
        <td>%s</td>
        <td>%d</td>
        <td>%s</td>
        <td>%d</td>
        <td>%d</td>
        <td>%d</td>
        <td>%d</td>
        <td>%s</td>
        <td class="stat-highlight">%s</td>
    </tr>
    ]], 
    name, mvpCell, 
    goals, assists, sog, ca, efPct, 
    passes, possession, 
    steals, err, 
    saves, gs, defPct, 
    rating)
end

return HtmlTemplates
