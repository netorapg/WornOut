function generateLevel() end
function chekItemCollection() end
function startNextLevel() end
function love.load()

    gridSize = 20
    gridWidth = 30
    gridHeight = 25

    math.randomseed(os.time())

    love.window.setMode(gridWidth * gridSize, gridHeight * gridSize + 40)
    love.window.setTitle("Worn Out")

    colors = {
        background = {75, 105, 47},
        foreground = {0, 0, 0},
        dark_wall = {20, 30, 15},
        player = {0, 0, 0},
        player_stuck = {170, 0, 0},
        light_timer = {15, 45, 0}
    }

    game = {
        level = 0,
        shopInterval = 5,
        nextShopLevel = 5
    }

    player = {
        battery = 150, -- Aumentei um pouco a bateria para o labirinto
        maxBattery = 150,
        moves = 0,
        score = 0,
        abilityRange = 1,
        abilityCooldown = 0, 
        visionRange = 6
    }

    shopItems = {
        {name="Powerbank", description="Aumenta a bateria máxima em 50."},
        {name = "Shockwave", description="Aumenta o alcance do [Space] em 1. "},
        {name="Scanner", description="Aumenta o alcance da visao do escuro."}
    }

    goal = {}
    abilityCost = 25
    abilityCooldownDuration = 15
    startNextLevel()
end

function startNextLevel()
    game.level = game.level + 1

    local levelType = "normal"
    local specialChance = math.random()
    if specialChance < 0.2 then
        levelType = "few_batteries"
    elseif specialChance < 0.4 then
        levelType = "more_traps"
    elseif specialChance < 0.55 then
        levelType = "dark"
    end

    game.currentLevelType = levelType
    game.lightTimer = 0
    game.isLit = false
    local generatedData = generateLevel(levelType)
    map = generatedData.map
    batteries = generatedData.batteries
    traps = generatedData.traps
    batteryItemValue = 50

    player.x = generatedData.playerStart.x
    player.y = generatedData.playerStart.y
    player.moves = 0
    player.battery = player.maxBattery
    player.isStuck = false

    goal.x = generatedData.goalPos.x
    goal.y = generatedData.goalPos.y

    gameState = "playing"

    decayInterval = 1
    decayTimer = 0

end

function updatePlayerStatus()
    player.isStuck = false
    for _, trap in ipairs(traps) do
        if player.x == trap.x and player.y == trap.y then
            player.isStuck = true
            break
        end
    end
end

function generateLevel(levelType)
    local numBatteries = 4
    local numTraps = 8

    if levelType == "few_batteries" then
        numBatteries = 1
    elseif levelType == "more_traps" then
        numTraps = 16
    elseif levelType == "dark" then
        numBatteries = 5
    end
    local newMap = {}
    for y = 1, gridHeight do
        newMap[y] = {}
        for x = 1, gridWidth do
            newMap[y][x] = 1
        end
    end

    local function carvePassages(cx, cy)
        local directions = {{0, -2}, {0, 2}, {-2, 0}, {2, 0}}

        for i = #directions, 2, -1 do
            local j = math.random(i)
            directions[i], directions[j] = directions[j], directions[i]
        end

        for _, dir in ipairs(directions) do
            local nx, ny = cx + dir[1], cy + dir[2]
            if ny > 1 and ny < gridHeight and nx > 1 and nx < gridWidth and newMap[ny][nx] == 1 then
                newMap[ny][nx] = 0
                newMap[ny - dir[2]/2][nx - dir[1]/2] = 0
                carvePassages(nx, ny)
            end
        end
    end

    local startX, startY = 3, 3
    newMap[startY][startX] = 0
    carvePassages(startX, startY)

    local availableSpots = {}
    for y = 2, gridHeight - 1 do
        for x = 2, gridWidth - 1 do
            if newMap[y][x] == 0 then
                table.insert(availableSpots, {x = x, y = y})
            end
        end
    end

    for i = #availableSpots, 2, -1 do
        local j = math.random(i)
        availableSpots[i], availableSpots[j] = availableSpots[j], availableSpots[i]
    end

    local playerStartPos = table.remove(availableSpots, 1)
    local goalPos = table.remove(availableSpots, 1)

    local newBatteries = {}
    for i = 1, numBatteries do
        if #availableSpots > 0 then
            local batteryPos = table.remove(availableSpots, 1)
            table.insert(newBatteries, batteryPos)
        end
    end

    local newTraps = {}
    for i = 1, numTraps do
        if #availableSpots > 0 then
            local trapPos = table.remove(availableSpots, 1)
            table.insert(newTraps, trapPos)
        end
    end

    return {
        map = newMap,
        playerStart = playerStartPos,
        goalPos = goalPos,
        batteries = newBatteries,
        traps = newTraps
    }
end

function love.update(dt)
    if gameState == "playing" then
        decayTimer = decayTimer + dt*5

        if decayTimer >= decayInterval then
            player.battery = player.battery - 1

            decayTimer = decayTimer - decayInterval
            
            if player.battery <= 0 then
                player.battery = 0
                gameState = "lost"
            end
        end

        if game.lightTimer > 0 then 
            game.lightTimer = game.lightTimer - dt
        end

        if player.abilityCooldown > 0 then
            player.abilityCooldown = player.abilityCooldown - dt
        end
    end
end

function love.keypressed(key)
    if gameState == "won" and key == "r" then
        player.score = (player.score + player.battery) - player.moves
        if game.level == game.nextShopLevel then
            gameState = "shop"
        else
            startNextLevel()
        end
        return
    elseif gameState == "lost" and key == "r" then
        love.load()
        return

    elseif gameState == "shop" then
        local choiceMade = false
        if key == "1" then
            player.maxBattery = player.maxBattery + 50
            choiceMade = true
        elseif key == "2" then
            player.abilityRange = player.abilityRange + 1
            choiceMade = true
        elseif key == "3" then
            player.visionRange = player.visionRange + 3
            choiceMade = true
        end

        if choiceMade then
            game.shopInterval = game.shopInterval * 2
            game.nextShopLevel = game.level + game.shopInterval
            startNextLevel()
        end
        return
    end
    if gameState ~= "playing" then return end

    if player.isStuck then
        if key == "up" or key == "down" or key == "left" or key == "right" then
            player.isStuck = false
            player.battery = player.battery - 1

            if player.battery <= 0 then
                player.battery = 0
                gameState = "lost"
            end
            return
        end
    end

    local moved = false
    local targetX, targetY = player.x, player.y

    if key == "up" then
        targetY = player.y - 1
        moved = true
    elseif key == "down" then
        targetY = player.y + 1
        moved = true
    elseif key == "left" then
        targetX = player.x - 1
        moved = true
    elseif key == "right" then
        targetX = player.x + 1
        moved = true
    elseif key == "space" then
        if player.battery > abilityCost and player.abilityCooldown <= 0 then
            player.battery = player.battery - abilityCost
            player.abilityCooldown = abilityCooldownDuration

               for dy = -player.abilityRange, player.abilityRange do
                for dx = -player.abilityRange, player.abilityRange do
                    if dx == 0 and dy == 0 then
                        
                    else
                        local pos = {x = player.x +dx, y = player.y + dy}
                        if pos.x > 1 and pos.x < gridWidth and pos.y > 1 and pos.y < gridHeight then
                            if map[pos.y][pos.x] == 1 then
                                map[pos.y][pos.x] = 0
                            end
                        end
                    end
                end
            end
            if player.battery <= 0 then
                player.battery = 0
                gameState = "lost"
            end
        end
        return
    else
        return -- Sai da função se não for uma tecla de movimento
    end
    
    if moved then
        if targetX >= 1 and targetX <= gridWidth and
            targetY >= 1 and targetY <= gridHeight and
            map[targetY][targetX] ~= 1 then -- A MÁGICA ACONTECE AQUI!
       
            player.x = targetX
            player.y = targetY
            player.battery = player.battery - 1
            player.moves = player.moves + 1
            checkItemCollection()
            updatePlayerStatus()
            if player.x == goal.x and player.y == goal.y then
                gameState = "won"
            elseif player.battery <= 0 then
                gameState = "lost"
            end
        end
    end
end

function checkItemCollection()
    for i = #batteries, 1, -1 do
        local item = batteries[i]
        if player.x == item.x and player.y == item.y then
            player.battery = player.battery + batteryItemValue
            if player.battery > player.maxBattery then
                player.battery = player.maxBattery
            end
            table.remove(batteries, i)

            if game.currentLevelType == "dark" then
                game.lightTimer = game.lightTimer + 10
            end
        end
    end
end


function love.draw()
    if gameState == "shop" then
        drawShop()
        return
    end
    
    love.graphics.clear(colors.background[1]/255, colors.background[2]/255, colors.background[3]/255)

    -- 1. Desenha o cenário e itens que podem ser escondidos
    -- Mapa e Grade
    love.graphics.setColor(colors.foreground)
    for y=1, gridHeight do
        for x=1, gridWidth do
            if map[y][x] == 1 then
                love.graphics.rectangle("fill", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
            end
        end
    end
    love.graphics.setColor(colors.dark_wall[1]/255, colors.dark_wall[2]/255, colors.dark_wall[3]/255)
    for i = 1, gridWidth do
        love.graphics.line(i * gridSize, 0, i * gridSize, gridHeight * gridSize)
    end
    for i = 1, gridHeight do
        love.graphics.line(0, i * gridSize, gridWidth * gridSize, i * gridSize)
    end
    -- Armadilhas e Objetivo
    love.graphics.setColor(colors.foreground)
    for _, trap in ipairs(traps) do
        love.graphics.circle("fill", (trap.x - 1) * gridSize + gridSize / 2, (trap.y - 1) * gridSize + gridSize / 2, gridSize / 3 )
    end
    love.graphics.setColor(0, 1, 0, 0.5) 
    love.graphics.rectangle("fill", (goal.x - 1) * gridSize, (goal.y - 1) * gridSize, gridSize, gridSize)

    -- 2. Aplica a máscara de escuridão (se necessário)
    if game.currentLevelType == "dark" and game.lightTimer <= 0 then
        local previousBlendMode = love.graphics.getBlendMode()
        love.graphics.setColor(0, 0, 0, 0.99)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setBlendMode("subtract")
        love.graphics.setColor(1, 1, 1)
        local lightX = (player.x - 0.5) * gridSize
        local lightY = (player.y - 0.5) * gridSize
        love.graphics.circle("fill", lightX, lightY, gridSize * 4)
        love.graphics.setBlendMode(previousBlendMode)

        love.graphics.setColor(colors.dark_wall[1]/255, colors.dark_wall[2]/255, colors.dark_wall[3]/255)
        local startX = math.max(1, player.x - player.visionRange)
        local endX = math.min(gridWidth, player.x + player.visionRange)
        local startY = math.max(1, player.y - player.visionRange)
        local endY = math.min(gridHeight, player.y + player.visionRange)
        for y = startY, endY do
            for x= startX, endX do
                if map[y][x] == 1 then
                    love.graphics.rectangle("line", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
                end
            end
        end
    end

    -- 3. Desenha elementos SEMPRE visíveis (por cima da escuridão)
    -- Baterias
    love.graphics.setColor(colors.foreground)
    for i, item in ipairs(batteries) do
        love.graphics.rectangle("fill", (item.x - 1) * gridSize + 4, (item.y - 1) * gridSize + 4, gridSize - 8, gridSize - 8)
    end
    -- Jogador
    if player.isStuck then
        love.graphics.setColor(colors.player_stuck[1]/255, colors.player_stuck[2]/255, colors.player_stuck[3]/255)
    else
        love.graphics.setColor(colors.player)
    end
    love.graphics.rectangle("fill", (player.x - 1) * gridSize, (player.y - 1) * gridSize, gridSize, gridSize)
    
    if game.lightTimer > 0 then
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.setColor(colors.light_timer[1]/255, colors.light_timer[2]/255, colors.light_timer[3]/255)
        local lightText = "Luz: " .. string.format("%.1f", game.lightTimer) .. "s"
        love.graphics.printf(lightText, love.graphics.getWidth() - 120, 10, 110, "right")
    end
    -- 4. Desenha a UI e as mensagens de fim de jogo
    drawUI()
    if gameState == "won" then
        love.graphics.setColor(colors.foreground)
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.printf("VOCÊ VENCEU!", 0, love.graphics.getHeight() / 2 - 60, love.graphics.getWidth(), "center")
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.printf("Bateria Restante: " .. player.battery, 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
        love.graphics.printf("Pontuação Total: " .. player.score, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.printf("Pressione R para o próximo nível", 0, love.graphics.getHeight() / 2 + 25, love.graphics.getWidth(), "center")
    elseif gameState == "lost" then
        love.graphics.setColor(colors.foreground)
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.printf("BATERIA ESGOTADA!", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Aperte 'R' para reiniciar", 0, love.graphics.getHeight() / 2 + 10, love.graphics.getWidth(), "center")
    
        if game.lightTimer > 0 then
            love.graphics.setColor(1, 1, 0.2)
            local lightText = "Luz: " .. string.format("%.1f", game.lightTimer) .. "s"
            love.graphics.printf(lightText, love.graphics.getWidth() / 2 - 75, uiY + 20, 150, "center")
        end
    end
end

function drawShop()
    love.graphics.clear(colors.foreground[1]/255, colors.foreground[2]/255, colors.foreground[3]/255)

    love.graphics.setColor(colors.background[1]/255, colors.background[2]/255, colors.background[3]/255)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf("LOJA DE UPGRADES", 0, 40, love.graphics.getWidth(), "center")

    love.graphics.setFont(love.graphics.newFont(16))
    -- Item 1: Powerbank
    love.graphics.printf("[1] " .. shopItems[1].name, 50, 130, 500, "left")
    love.graphics.printf(shopItems[1].description, 70, 160, 450, "left")

    -- Item 2: Shockwave
    love.graphics.printf("[2] " .. shopItems[2].name, 50, 220, 500, "left")
    love.graphics.printf(shopItems[2].description, 70, 250, 450, "left")

    -- Item 3: Scanner
    love.graphics.printf("[3] " .. shopItems[3].name, 50, 310, 500, "left")
    love.graphics.printf(shopItems[3].description, 70, 340, 450, "left")

    love.graphics.printf("Sua escolha te levara para o proximo nivel.", 0, love.graphics.getHeight() - 80, love.graphics.getWidth(), "center")
end


function drawUI()
    local uiY = gridHeight * gridSize + 5

    love.graphics.setColor(colors.foreground)
    love.graphics.rectangle("fill", 0, gridHeight * gridSize, love.graphics.getWidth(), 40)

    -- Bateria (diminuída)
    love.graphics.setColor(colors.dark_wall[1]/255, colors.dark_wall[2]/255, colors.dark_wall[3]/255)
    local maxBatteryBarWidth = 120 -- Diminuído de 200 para 120
    love.graphics.rectangle("fill", 10, uiY, maxBatteryBarWidth, 25) -- Altura também diminuída

    love.graphics.setColor(0, 1, 0)
    local batteryWidth = (player.battery / player.maxBattery) * maxBatteryBarWidth
    love.graphics.rectangle("fill", 10, uiY, batteryWidth, 25)

    -- Texto da bateria
    love.graphics.setColor(colors.background[1]/255, colors.background[2]/255, colors.background[3]/255)
    love.graphics.setFont(love.graphics.newFont(14)) -- Fonte um pouco menor
    love.graphics.printf(player.battery .. "/" .. player.maxBattery, 10, uiY + 5, maxBatteryBarWidth, "center")

    love.graphics.printf("Movimentos: " .. player.moves, 140, uiY + 5, 120, "left")

  
    -- Instruções (compactadas)
   

    -- Pontuação (melhor alinhada)
    love.graphics.printf("Pontuação: " .. player.score, love.graphics.getWidth() - 150, uiY + 5, 140, "right")

    love.graphics.printf("Nivel: " .. game.level, 140, uiY + 20, 120, "left")

     if player.abilityCooldown > 0 then
        love.graphics.setColor(colors.player_stuck[1]/255, colors.player_stuck[2]/255, colors.player_stuck[3]/255)
        local cooldownText = "Recarregando: " .. string.format("%.1f", player.abilityCooldown) .. "s"
        love.graphics.printf(cooldownText, 270, uiY + 5, 180, "left")
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("[Space] Quebrar (" .. abilityCost .. ")", 270, uiY + 5, 180, "left")
    end
end