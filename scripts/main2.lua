-- ============================================================
--  GAMEMODE BASE — libgroup
--  Arquivo único: main.lua
--  Versão: 0.1.0
-- ============================================================
--
--  ESTRUTURA DE DADOS DO JOGADOR
--  {
--      id           : number   — auto-incremento
--      nome         : string   — apelido opcional (vazio por ora)
--      username     : string
--      password     : string   — plaintext agora; hash na migração MySQL
--      carteira     : number   — dinheiro em mão (R$)
--      banco        : number   — saldo bancário  (R$)
--      dataCriacao  : string   — "DD/MM/AAAA"
--      lastLogin    : string   — "DD/MM/AAAA"
--      diasJogados  : number
--      banned       : boolean
--      adm          : boolean
--  }
--
--  COMANDOS
--      /registrar <user> <senha>
--      /login     <user> <senha>
--      /perfil
--      /ban       <nome do jogador>   (apenas ADM)
--      /setadm    <nome do jogador>   (apenas ADM)
--
-- ============================================================


-- ============================================================
-- [1] CONFIGURAÇÕES
-- ============================================================

local DB_PATH = "players.json"

-- Prefeitura (City Hall) — Pershing Square, Los Santos
local SPAWN_CITY = {
    x   =  1481.8,
    y   = -1716.4,
    z   =  18.795,
    rot =  0,
    skin = 0,
}

-- Hospital perto da Grove Street — All Saints General
local SPAWN_HOSPITAL = {
    x   =  1187.2,
    y   = -1374.1,
    z   =  13.546,
    rot =  270,
    skin = 0,
}


-- ============================================================
-- [2] BANCO DE DADOS LOCAL (JSON)
-- ============================================================

-- Estrutura em memória:
--   db.players  = { [serial] = { dados do jogador } }
--   db.nextID   = número do próximo ID
local db = { players = {}, nextID = 1 }

local function dbLoad()
    if not fileExists(DB_PATH) then
        outputDebugString("[DB] Arquivo não encontrado, começando do zero.")
        return
    end

    local f = fileOpen(DB_PATH, true)   -- true = somente leitura
    if not f then
        outputDebugString("[DB] ERRO: não foi possível abrir " .. DB_PATH)
        return
    end

    local size = fileGetSize(f)
    if size > 0 then
        local raw    = fileRead(f, size)
        local parsed = fromJSON(raw)
        if parsed then
            db = parsed
        else
            outputDebugString("[DB] ERRO: JSON corrompido. DB resetado.")
        end
    end

    fileClose(f)
end

local function dbSave()
    -- Apaga e recria para garantir sobrescrita limpa
    if fileExists(DB_PATH) then
        fileDelete(DB_PATH)
    end

    local f = fileCreate(DB_PATH)
    if not f then
        outputDebugString("[DB] ERRO: não foi possível salvar o banco de dados!")
        return
    end

    fileWrite(f, toJSON(db))
    fileClose(f)
end

-- Helpers de contagem (serial = string, então # não funciona)
local function dbCount()
    local n = 0
    for _ in pairs(db.players) do n = n + 1 end
    return n
end


-- ============================================================
-- [3] OPERAÇÕES DE JOGADOR
-- ============================================================

local function getSerial(player)
    return getPlayerSerial(player)
end

local function playerExists(serial)
    return db.players[serial] ~= nil
end

-- Verifica se um username já está em uso (qualquer conta)
local function usernameExists(username)
    for _, data in pairs(db.players) do
        if data.username:lower() == username:lower() then
            return true
        end
    end
    return false
end

local function getDateString()
    local t = getRealTime()
    return string.format("%02d/%02d/%04d",
        t.monthday,
        t.month + 1,
        t.year + 1900
    )
end

local function createPlayerData(serial, username, password)
    local today = getDateString()
    db.players[serial] = {
        id          = db.nextID,
        nome        = "",
        username    = username,
        password    = password,
        carteira    = 500,       -- grana inicial
        banco       = 0,
        dataCriacao = today,
        lastLogin   = today,
        diasJogados = 1,
        banned      = false,
        adm         = false,
    }
    db.nextID = db.nextID + 1
    dbSave()
    return db.players[serial]
end

local function getPlayerData(serial)
    return db.players[serial]
end

-- Atualiza lastLogin e conta dias jogados únicos
local function updateLoginStats(serial)
    local data  = db.players[serial]
    local today = getDateString()
    if data.lastLogin ~= today then
        data.diasJogados = data.diasJogados + 1
        data.lastLogin   = today
    end
    dbSave()
end


-- ============================================================
-- [4] SESSÕES (estado em memória enquanto o player está online)
-- ============================================================

--  sessions[player] = {
--      logged : bool,
--      serial : string,
--  }
local sessions = {}

local function isLogged(player)
    return sessions[player] and sessions[player].logged
end


-- ============================================================
-- [5] SPAWN
-- ============================================================

local function spawnAtCity(player)
    local s = SPAWN_CITY
    spawnPlayer(player, s.x, s.y, s.z, s.rot, s.skin)
    setCameraTarget(player, player)
    fadeCamera(player, true)
    outputChatBox(
        "📍 Você está na Prefeitura. Bem-vindo à cidade!",
        player, 80, 220, 120
    )
end

local function spawnAtHospital(player)
    local s = SPAWN_HOSPITAL
    spawnPlayer(player, s.x, s.y, s.z, s.rot, s.skin)
    setCameraTarget(player, player)
    fadeCamera(player, true)
    outputChatBox(
        "🏥 Você acordou no hospital. Tome cuidado!",
        player, 220, 80, 80
    )
end


-- ============================================================
-- [6] UI DE LOGIN (chat simples — tela gráfica virá depois)
-- ============================================================

local function showLoginScreen(player)
    outputChatBox(" ", player)
    outputChatBox(
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        player, 80, 160, 255
    )
    outputChatBox(
        "  Bem-vindo ao servidor!",
        player, 255, 255, 255
    )
    outputChatBox(
        "  /registrar <user> <senha>",
        player, 200, 200, 200
    )
    outputChatBox(
        "  /login     <user> <senha>",
        player, 200, 200, 200
    )
    outputChatBox(
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        player, 80, 160, 255
    )
    outputChatBox(" ", player)
end


-- ============================================================
-- [7] EVENTOS
-- ============================================================

addEventHandler("onResourceStart", resourceRoot, function()
    dbLoad()
    outputDebugString(
        "[GM] Gamemode iniciada — Jogadores no DB: " .. dbCount()
    )
end)

addEventHandler("onResourceStop", resourceRoot, function()
    dbSave()
    outputDebugString("[GM] Gamemode encerrada — DB salvo.")
end)

-- Jogador entra no servidor
addEventHandler("onPlayerJoin", root, function()
    local player = source
    local serial = getSerial(player)

    sessions[player] = { logged = false, serial = serial }

    -- Câmera parada na prefeitura enquanto não loga
    fadeCamera(player, false)
    setCameraMatrix(
        player,
        1467, -1710, 28,   -- posição da câmera
        1481, -1716, 18    -- ponto que a câmera olha
    )

    showLoginScreen(player)
end)

-- Jogador sai do servidor
addEventHandler("onPlayerQuit", root, function()
    local player = source
    if isLogged(player) then
        dbSave()
    end
    sessions[player] = nil
end)

-- Jogador morreu → respawna no hospital após 3s
addEventHandler("onPlayerWasted", root, function()
    local player = source
    if not isLogged(player) then return end

    setTimer(function()
        if isElement(player) then
            spawnAtHospital(player)
        end
    end, 3000, 1)
end)


-- ============================================================
-- [8] COMANDOS
-- ============================================================

-- /registrar <user> <senha>
addCommandHandler("registrar", function(player, _, username, password)
    if isLogged(player) then
        outputChatBox("[!] Você já está logado.", player, 255, 100, 100)
        return
    end

    if not username or not password then
        outputChatBox(
            "[!] Uso: /registrar <usuário> <senha>",
            player, 255, 100, 100
        )
        return
    end

    local serial = getSerial(player)

    if playerExists(serial) then
        outputChatBox(
            "[!] Seu serial já tem conta. Use /login.",
            player, 255, 100, 100
        )
        return
    end

    if usernameExists(username) then
        outputChatBox(
            "[!] Esse usuário já está em uso.",
            player, 255, 100, 100
        )
        return
    end

    local data = createPlayerData(serial, username, password)

    sessions[player].logged = true

    outputChatBox(
        "✔ Conta criada! ID #" .. data.id
        .. "  |  Carteira: R$" .. data.carteira,
        player, 80, 220, 120
    )

    spawnAtCity(player)
end)

-- /login <user> <senha>
addCommandHandler("login", function(player, _, username, password)
    if isLogged(player) then
        outputChatBox("[!] Você já está logado.", player, 255, 100, 100)
        return
    end

    if not username or not password then
        outputChatBox(
            "[!] Uso: /login <usuário> <senha>",
            player, 255, 100, 100
        )
        return
    end

    local serial = getSerial(player)

    if not playerExists(serial) then
        outputChatBox(
            "[!] Conta não encontrada. Use /registrar.",
            player, 255, 100, 100
        )
        return
    end

    local data = getPlayerData(serial)

    if data.username ~= username or data.password ~= password then
        outputChatBox(
            "[!] Usuário ou senha incorretos.",
            player, 255, 100, 100
        )
        return
    end

    if data.banned then
        kickPlayer(player, "Você está banido deste servidor.")
        return
    end

    sessions[player].logged = true
    updateLoginStats(serial)

    outputChatBox(
        "✔ Login efetuado! Olá, " .. data.username
        .. "  |  Carteira: R$" .. data.carteira
        .. "  |  Dias jogados: " .. data.diasJogados,
        player, 80, 220, 120
    )

    spawnAtCity(player)
end)

-- /perfil
addCommandHandler("perfil", function(player)
    if not isLogged(player) then
        outputChatBox("[!] Faça login primeiro.", player, 255, 100, 100)
        return
    end

    local data = getPlayerData(sessions[player].serial)
    if not data then return end

    local admTag    = data.adm    and "✔" or "✘"
    local bannedTag = data.banned and "✔" or "✘"

    outputChatBox(
        "━━━━━━━━ SEU PERFIL ━━━━━━━━",
        player, 80, 160, 255
    )
    outputChatBox(
        "  ID: #" .. data.id
        .. "  |  Usuário: " .. data.username,
        player, 255, 255, 255
    )
    outputChatBox(
        "  Carteira: R$" .. data.carteira
        .. "  |  Banco: R$" .. data.banco,
        player, 255, 255, 255
    )
    outputChatBox(
        "  Criado em: " .. data.dataCriacao
        .. "  |  Dias jogados: " .. data.diasJogados,
        player, 255, 255, 255
    )
    outputChatBox(
        "  ADM: " .. admTag
        .. "  |  Banido: " .. bannedTag,
        player, 255, 255, 255
    )
    outputChatBox(
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        player, 80, 160, 255
    )
end)

-- /ban <nome>  (ADM)
addCommandHandler("ban", function(player, _, targetName)
    if not isLogged(player) then return end

    local myData = getPlayerData(sessions[player].serial)
    if not myData or not myData.adm then
        outputChatBox("[!] Sem permissão.", player, 255, 100, 100)
        return
    end

    if not targetName then
        outputChatBox("[!] Uso: /ban <nome do jogador>", player, 255, 100, 100)
        return
    end

    local target = getPlayerFromName(targetName)
    if not target then
        outputChatBox("[!] Jogador não encontrado online.", player, 255, 100, 100)
        return
    end

    local targetSerial = getSerial(target)
    if db.players[targetSerial] then
        db.players[targetSerial].banned = true
        dbSave()
        kickPlayer(target, "Você foi banido do servidor.")
        outputChatBox(
            "✔ " .. getPlayerName(target) .. " foi banido.",
            player, 80, 220, 120
        )
    else
        outputChatBox("[!] Esse jogador não tem conta registrada.", player, 255, 100, 100)
    end
end)

-- /setadm <nome>  (ADM)
addCommandHandler("setadm", function(player, _, targetName)
    if not isLogged(player) then return end

    local myData = getPlayerData(sessions[player].serial)
    if not myData or not myData.adm then
        outputChatBox("[!] Sem permissão.", player, 255, 100, 100)
        return
    end

    if not targetName then
        outputChatBox("[!] Uso: /setadm <nome do jogador>", player, 255, 100, 100)
        return
    end

    local target = getPlayerFromName(targetName)
    if not target then
        outputChatBox("[!] Jogador não encontrado online.", player, 255, 100, 100)
        return
    end

    local targetSerial = getSerial(target)
    if db.players[targetSerial] then
        db.players[targetSerial].adm = true
        dbSave()
        outputChatBox(
            "✔ " .. getPlayerName(target) .. " agora é ADM.",
            player, 80, 220, 120
        )
        outputChatBox(
            "Você foi promovido a Administrador!",
            target, 255, 200, 0
        )
    else
        outputChatBox("[!] Esse jogador não tem conta registrada.", player, 255, 100, 100)
    end
end)

-- ============================================================
-- FIM DO ARQUIVO
-- ============================================================
