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

    game = {
        level = 0
    }

    player = {
        battery = 150, -- Aumentei um pouco a bateria para o labirinto
        maxBattery = 150,
        moves = 0,
        score = 0,
        abilityRange = 1
    }

    shopItems = {
        {name="Powerbank", description="Aumenta a bateria máxima em 50."},
        {name = "Shockwave", description="Aumenta o alcance do [Space] em 1. "}
    }

    goal = {}
    abilityCost = 25
    startNextLevel()
end

function startNextLevel()
    game.level = game.level + 1
    local generatedData = generateLevel()
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

function generateLevel()
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
    local numBatteries = 4
    for i = 1, numBatteries do
        if #availableSpots > 0 then
            local batteryPos = table.remove(availableSpots, 1)
            table.insert(newBatteries, batteryPos)
        end
    end

    local newTraps = {}
    local numTraps = 8 
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
        decayTimer = decayTimer + dt

        if decayTimer >= decayInterval then
            player.battery = player.battery - 1

            decayTimer = decayTimer - decayInterval
            
            if player.battery <= 0 then
                player.battery = 0
                gameState = "lost"
            end
        end
    end
end

function love.keypressed(key)
    if gameState == "won" and key == "r" then
        player.score = (player.score + player.battery) - player.moves
        if game.level > 0 and game.level % 5 == 0 then
            gameState = "shop"
        else
            startNextLevel()
        end
        return
    elseif gameState == "lost" and key == "r" then
        love.load()
        return

    elseif gameState == "shop" then
        if key == "1" then
            player.maxBattery = player.maxBattery + 50
            startNextLevel()
        elseif key == "2" then
            player.abilityRange = player.abilityRange + 1
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
        if player.battery > abilityCost then
            player.battery = player.battery - abilityCost

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
            table.remove(batteries, i) -- Remove o item coletado
        end
    end
end



function love.draw()
    if gameState == "shop" then
        drawShop()
        return
    end
    -- Limpa a tela com uma cor de fundo
    love.graphics.clear(0.15, 0.15, 0.15)

    --- NOVO: Desenha o mapa (chão e paredes)
    for y=1, gridHeight do
        for x=1, gridWidth do
            if map[y][x] == 1 then -- Se for uma parede
                love.graphics.setColor(0.5, 0.5, 0.5) -- Cor cinza para paredes
                love.graphics.rectangle("fill", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
            end
        end
    end

    -- Desenha a grade por cima (opcional, mas fica legal)
    love.graphics.setColor(0.2, 0.2, 0.2)
    for i = 1, gridWidth do
        love.graphics.line(i * gridSize, 0, i * gridSize, gridHeight * gridSize)
    end
    for i = 1, gridHeight do
        love.graphics.line(0, i * gridSize, gridWidth * gridSize, i * gridSize)
    end

    love.graphics.setColor(0.6, 0.2, 0.8, 0.8)
    for _, trap in ipairs(traps) do
        love.graphics.circle("fill", (trap.x - 1) * gridSize + gridSize / 2, (trap.y - 1) * gridSize + gridSize / 2, gridSize / 3 )
    end

    -- Desenha o objetivo
    love.graphics.setColor(0, 1, 0, 0.5) 
    love.graphics.rectangle("fill", (goal.x - 1) * gridSize, (goal.y - 1) * gridSize, gridSize, gridSize)

     love.graphics.setColor(1, 0.8, 0) -- Cor amarela/laranja para as baterias
    for i, item in ipairs(batteries) do
        love.graphics.rectangle("fill", (item.x - 1) * gridSize + 4, (item.y - 1) * gridSize + 4, gridSize - 8, gridSize - 8)
    end
    -- Desenha o jogador
    love.graphics.setColor(0.2, 0.6, 1) -- Mudei a cor do jogador para um azul mais vivo
    love.graphics.rectangle("fill", (player.x - 1) * gridSize, (player.y - 1) * gridSize, gridSize, gridSize)

    if player.isStuck then
        love.graphics.setColor(1, 0.2, 0.2)
    else
        love.graphics.setColor(0.2, 0.6, 1)
    end
    love.graphics.rectangle("fill", (player.x - 1) * gridSize, (player.y - 1) * gridSize, gridSize, gridSize)

    -- Desenha a UI
    drawUI()

    -- Mensagens de vitória/derrota (sem alteração)
   if gameState == "won" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(32)) -- Diminuí de 40 para 32
        love.graphics.printf("VOCÊ VENCEU!", 0, love.graphics.getHeight() / 2 - 60, love.graphics.getWidth(), "center")
        
        love.graphics.setFont(love.graphics.newFont(16)) -- Diminuí de 20 para 16
        love.graphics.printf("Bateria Restante: " .. player.battery, 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
        love.graphics.printf("Pontuação Total: " .. player.score, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.printf("Pressione R para o próximo nível", 0, love.graphics.getHeight() / 2 + 25, love.graphics.getWidth(), "center")
    elseif gameState == "lost" then
        love.graphics.setColor(1, 0, 0)
        love.graphics.setFont(love.graphics.newFont(32)) -- Diminuí de 40 para 32
        love.graphics.printf("BATERIA ESGOTADA!", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        
        love.graphics.setFont(love.graphics.newFont(16)) -- Diminuí de 20 para 16
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Aperte 'R' para reiniciar", 0, love.graphics.getHeight() / 2 + 10, love.graphics.getWidth(), "center")
    end

    
end

function drawShop()
    love.graphics.clear(0.1, 0.1, 0.2)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf("LOJA DE UPGRADES", 0, 40, love.graphics.getWidth(), "center")

    love.graphics.setFont(love.graphics.newFont(16))
    -- Item 1: Powerbank
    love.graphics.printf("[1] " .. shopItems[1].name, 50, 150, 500, "left")
    love.graphics.printf(shopItems[1].description, 70, 180, 450, "left")

    -- Item 2: Shockwave
    love.graphics.printf("[2] " .. shopItems[1].name, 50, 260, 500, "left")
    love.graphics.printf(shopItems[2].description, 70, 180, 450, "left")

    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Sua escolha te levara para o proximo nivel.", 0, love.graphics.getHeight() - 80, love.graphics.getWidth(), "center")
end


function drawUI()
    local uiY = gridHeight * gridSize + 5

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, gridHeight * gridSize, love.graphics.getWidth(), 40)

    -- Bateria (diminuída)
    love.graphics.setColor(1, 0, 0)
    local maxBatteryBarWidth = 120 -- Diminuído de 200 para 120
    love.graphics.rectangle("fill", 10, uiY, maxBatteryBarWidth, 25) -- Altura também diminuída

    love.graphics.setColor(0, 1, 0)
    local batteryWidth = (player.battery / player.maxBattery) * maxBatteryBarWidth
    love.graphics.rectangle("fill", 10, uiY, batteryWidth, 25)

    -- Texto da bateria
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(14)) -- Fonte um pouco menor
    love.graphics.printf(player.battery .. "/" .. player.maxBattery, 10, uiY + 5, maxBatteryBarWidth, "center")

    -- Movimentos (melhor posicionado)
    love.graphics.printf("Movimentos: " .. player.moves, 140, uiY + 5, 120, "left")

    -- Instruções (compactadas)
    love.graphics.printf("[Space] Quebrar (" .. abilityCost .. ")", 270, uiY + 5, 180, "left")

    -- Pontuação (melhor alinhada)
    love.graphics.printf("Pontuação: " .. player.score, love.graphics.getWidth() - 150, uiY + 5, 140, "right")

    love.graphics.printf("Nivel: " .. game.level, 140, uiY + 20, 120, "left")
end