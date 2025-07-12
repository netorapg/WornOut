function generateLevel() end
function chekItemCollection() end
function love.load()

    gridSize = 20
    gridWidth = 30
    gridHeight = 25

    math.randomseed(os.time())

    love.window.setMode(gridWidth * gridSize, gridHeight * gridSize + 40)
    love.window.setTitle("Worn Out")

    gameState = "playing"

   local generatedData = generateLevel()

    map = generatedData.map
    batteries = generatedData.batteries
    batteryItemValue = 50

    player = {
        x = generatedData.playerStart.x,
        y = generatedData.playerStart.y, 
        battery = 150, -- Aumentei um pouco a bateria para o labirinto
        maxBattery = 150,
        moves = 0
    }

    goal = {
        x = generatedData.goalPos.x,
        y = generatedData.goalPos.y
    }
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

    return {
        map = newMap,
        playerStart = playerStartPos,
        goalPos = goalPos,
        batteries = newBatteries
    }
end

function love.update(dt)
    -- Nenhuma mudança aqui
end

function love.keypressed(key)
    if gameState ~= "playing" then
        if key == "r" then
            love.load()
        end
        return
    end

    --- ALTERADO: Lógica de movimento agora checa por paredes
    local targetX, targetY = player.x, player.y

    if key == "up" then
        targetY = player.y - 1
    elseif key == "down" then
        targetY = player.y + 1
    elseif key == "left" then
        targetX = player.x - 1
    elseif key == "right" then
        targetX = player.x + 1
    else
        return -- Sai da função se não for uma tecla de movimento
    end
    
    -- Checa se o movimento é válido (dentro do grid E não é uma parede)
    if targetX >= 1 and targetX <= gridWidth and
       targetY >= 1 and targetY <= gridHeight and
       map[targetY][targetX] ~= 1 then -- A MÁGICA ACONTECE AQUI!
       
        -- Se for válido, move o jogador e gasta bateria
        player.x = targetX
        player.y = targetY
        player.battery = player.battery - 1
        player.moves = player.moves + 1

        checkItemCollection()

        -- Checa condição de vitória/derrota
        if player.x == goal.x and player.y == goal.y then
            gameState = "won"
        elseif player.battery <= 0 then
            gameState = "lost"
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

    -- Desenha a UI
    drawUI()

    -- Mensagens de vitória/derrota (sem alteração)
    if gameState == "won" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(40))
        love.graphics.printf("VOCE VENCEU!", 0, love.graphics.getHeight() / 2 - 50, love.graphics.getWidth(), "center")
        love.graphics.setFont(love.graphics.newFont(20))
        local score = player.battery
        love.graphics.printf("Pontuação: " .. score .. " | Movimentos: " .. player.moves, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.printf("Pressione R para reiniciar", 0, love.graphics.getHeight() / 2 + 30, love.graphics.getWidth(), "center")
    elseif gameState == "lost" then
        love.graphics.setColor(1, 0, 0)
        love.graphics.setFont(love.graphics.newFont(40))
        love.graphics.printf("BATERIA ESGOTADA!", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Aperte 'R' para reiniciar", 0, love.graphics.getHeight() / 2 + 20, love.graphics.getWidth(), "center")
    end
end



function drawUI()
    -- Nenhuma mudança aqui
    local uiY = gridHeight * gridSize + 5

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, gridHeight * gridSize, love.graphics.getWidth(), 40)

    love.graphics.setColor(1, 0, 0)
    local maxBatteryBarWidth = 200
    love.graphics.rectangle("fill", 10, uiY, maxBatteryBarWidth, 30)

    love.graphics.setColor(0, 1, 0)
    -- ALTERADO: O cálculo da barra agora usa a bateria máxima
    local batteryWidth = (player.battery / player.maxBattery) * maxBatteryBarWidth
    love.graphics.rectangle("fill", 10, uiY, batteryWidth, 30)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf(player.battery .. "/" .. player.maxBattery, 10, uiY + 7, maxBatteryBarWidth, "center")

    love.graphics.printf("Movimentos: " .. player.moves, 230, uiY + 7, 200, "left")
end