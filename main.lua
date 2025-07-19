local anim8 = require 'anim8'
function generateLevel() end
function checkItemCollection() end
function startNextLevel() end
function love.load()
    gridSize = 20
    gridWidth = 30
    gridHeight = 25

    math.randomseed(os.time())

    love.window.setMode(gridWidth * gridSize, gridHeight * gridSize + 40)
    love.window.setTitle("Worn Out")
    
    -- 1. Load image and create grid (using dimensions for new anim8)
    local spritesheet = love.graphics.newImage("assets/sprite_sheet.png")
    local g = anim8.newGrid(20, 20, spritesheet:getWidth(), spritesheet:getHeight())

    -- 2. Define 'sprites' table FIRST AND COMPLETELY
    sprites = {
        sheet = spritesheet,
        target = g(2, 3)[1],
        battery  = g(3, 3)[1],
        trap = g(3, 5)[1],
        shop_powerbank = g(1, 6)[1],
        shop_shockwave = g(2, 6)[1],
        shop_scanner   = g(3, 6)[1]
    }
    sprites.player = {
        idle    = anim8.newAnimation( g('2-3', 1), 0.25 ),
        trapped   = anim8.newAnimation( g(4, 1), 0.3 ),
        dead   = anim8.newAnimation( g('1-2', 2), 1 ),
        impulse = anim8.newAnimation( g('4-4', 1), 0.1, 'pauseAtEnd' )
    }
    
    -- Load audio files
    audio = {
        music = love.audio.newSource("assets/wornout.mp3", "stream"),
        explosion = love.audio.newSource("assets/explosion.wav", "static")
    }
    
    -- Configure music to loop
    audio.music:setLooping(true)
    audio.music:setVolume(0.6)
    audio.explosion:setVolume(0.8)
    
    -- Start music
    audio.music:play()
    
    -- 3. Define other tables
    colors = {
        background = {75, 105, 47},
        foreground = {0, 0, 0},
        dark_wall = {20, 30, 15},
        player_stuck = {170, 0, 0},
        light_timer = {15, 45, 0},
        player = {255, 255, 255}
    }

    game = {
        level = 0,
        shopInterval = 3,  -- Changed from 5 to 3 (shop every 3 levels)
        nextShopLevel = 3  -- Changed from 5 to 3
    }

    -- 4. Now that 'sprites' and 'sprites.player' exist, we can create 'player' table
    player = {
        battery = 100,
        maxBattery = 100,
        moves = 0,
        score = 0,
        abilityRange = 1,
        abilityCooldown = 0, 
        visionRange = 6,
        currentAnim = sprites.player.idle,
        boostAnimTimer = 0
    }

    screenShake = {
        duration = 0,
        intensity = 0,
        x = 0, 
        y = 0
    }

    shopItems = {
        {name="Powerbank", description="Increases maximum battery by 50."},
        {name = "Shockwave", description="Increases [Space] range by 1(increase cost). "},
        {name="Scanner", description="Increases vision range in the dark."}
    }

    goal = {}
    abilityCost = 25
    abilityCooldownDuration = 15

    -- Add glow effect for the goal
    goalGlow = {
        timer = 0,
        intensity = 0
    }

    -- NEW: Creates single pixel texture for colored particles
    local imageData = love.image.newImageData(1, 1)
    imageData:setPixel(0, 0, 1, 1, 1, 1) -- White pixel
    local particleTexture = love.graphics.newImage(imageData)

    -- FIXED: Particle system configuration
    wallDebris = love.graphics.newParticleSystem(particleTexture, 100)
    wallDebris:setParticleLifetime(0.3, 0.8)
    wallDebris:setEmissionRate(500)
    wallDebris:setLinearDamping(3)
    wallDebris:setColors(20/255, 30/255, 15/255, 1, 20/255, 30/255, 15/255, 0)
    wallDebris:setSpread(math.pi * 2)
    wallDebris:setSpeed(80, 150)
    wallDebris:setLinearAcceleration(0, 300, 0, 400)
    wallDebris:setSizes(3, 1)
    wallDebris:setSizeVariation(1)
    activeParticles = {}
    
    -- Menu settings
    menu = {
        blinkTimer = 0,
        showText = true
    }
    
    -- Generate background maze for menu
    generateMenuBackground()
    
    -- Start in menu
    gameState = "menu"
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
    elseif specialChance < 0.7 then
        levelType = "low_energy"
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
    player.isStuck = false

    -- Aplica o efeito de low_energy aqui
    if levelType == "low_energy" then
        player.battery = 50
    else
        player.battery = player.maxBattery
    end

    goal.x = generatedData.goalPos.x
    goal.y = generatedData.goalPos.y

    -- Reset goal glow
    goalGlow.timer = 0
    goalGlow.intensity = 0

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
    updatePlayerAnimation()
end

function updatePlayerAnimation()
    if player.boostAnimTimer > 0 then return end
    if gameState == "lost" then
        player.currentAnim = sprites.player.dead
    elseif player.isStuck then
        player.currentAnim = sprites.player.trapped
    else
        player.currentAnim = sprites.player.idle
    end
end

function generateLevel(levelType)
    local numBatteries = 4
    local numTraps = 8

    if levelType == "few_batteries" then
        numBatteries = 1
    elseif levelType == "more_traps" then
        numTraps = 16
    elseif levelType == "low_energy" then
        player.battery = 50
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
    if gameState == "menu" then
        menu.blinkTimer = menu.blinkTimer + dt
        if menu.blinkTimer >= 0.5 then
            menu.showText = not menu.showText
            menu.blinkTimer = 0
        end
        return
    end
    
    if gameState == "playing" then
        -- Update goal glow animation
        goalGlow.timer = goalGlow.timer + dt * 3 -- Speed of pulsing
        goalGlow.intensity = (math.sin(goalGlow.timer) + 1) * 0.5 -- Value between 0 and 1
        
        decayTimer = decayTimer + dt

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
        
        if player.boostAnimTimer > 0 then
            player.boostAnimTimer = player.boostAnimTimer - dt
            if player.boostAnimTimer <= 0 then
                updatePlayerAnimation()
            end
        end

        -- Update screen shake
        if screenShake.duration > 0 then
            screenShake.duration = screenShake.duration - dt
            screenShake.x = (math.random() - 0.5) * screenShake.intensity
            screenShake.y = (math.random() - 0.5) * screenShake.intensity
            
            if screenShake.duration <= 0 then
                screenShake.x = 0
                screenShake.y = 0
            end
        end
    end
    
    for i = #activeParticles, 1, -1 do
        local ps = activeParticles[i]
        ps:update(dt)
        if ps:getCount() == 0 then
            table.remove(activeParticles, i)
        end
    end
    player.currentAnim:update(dt)
end

function resetGame()
    player.battery = 100
    player.maxBattery = 100
    player.moves = 0
    player.score = 0
    player.abilityRange = 1
    player.abilityCooldown = 0
    player.visionRange = 6
    player.currentAnim = sprites.player.idle
    player.boostAnimTimer = 0
    game.level = 0
    game.shopInterval = 3
    game.nextShopLevel = 3
    gameState = "menu"
end

function love.keypressed(key)
    if gameState == "menu" then
        if key == "space" or key == "return" or key == "enter" then
            startNextLevel()
            return
        end
        return
    end
    
    if gameState == "won" and key == "r" then
        local newScore = (player.score + player.battery) - player.moves
        player.score = math.max(0, newScore)
        -- Check if it's time for shop (every 3 levels)
        if game.level % 3 == 0 then
            gameState = "shop"
        else
            startNextLevel()
        end
        return
    elseif gameState == "lost" and key == "r" then
        resetGame()
        return

    elseif gameState == "shop" then
        local choiceMade = false
        if key == "1" then
            player.maxBattery = player.maxBattery + 5
            choiceMade = true
        elseif key == "2" then
            player.abilityRange = player.abilityRange + 1
            abilityCost = abilityCost + 25
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
            -- Play explosion sound
            audio.explosion:stop() -- Stop sound if already playing
            audio.explosion:play()
            
            player.battery = player.battery - abilityCost
            player.abilityCooldown = abilityCooldownDuration
            
            -- Add screen shake
            screenShake.duration = 0.3
            screenShake.intensity = 8
            
            for dy = -player.abilityRange, player.abilityRange do
                for dx = -player.abilityRange, player.abilityRange do
                    if dx == 0 and dy == 0 then
                        
                    else
                        local pos = {x = player.x +dx, y = player.y + dy}
                        if pos.x > 1 and pos.x < gridWidth and pos.y > 1 and pos.y < gridHeight then
                            if map[pos.y][pos.x] == 1 then
                                map[pos.y][pos.x] = 0

                                local debrisEffect = wallDebris:clone()
                                debrisEffect:setPosition((pos.x - 0.5) * gridSize, (pos.y - 0.5) * gridSize)
                                debrisEffect:emit(30)
                                debrisEffect:stop()
                                table.insert(activeParticles, debrisEffect)
                            end
                        end
                    end
                end
            end
            if player.battery <= 0 then
                player.battery = 0
                gameState = "lost"
            end
            player.currentAnim = sprites.player.impulse
            player.currentAnim:gotoFrame(1)
            player.boostAnimTimer = 0.1
        end
        return
        
    else
        return -- Exit function if not a movement key
    end
    
    if moved then
        if targetX >= 1 and targetX <= gridWidth and
            targetY >= 1 and targetY <= gridHeight and
            map[targetY][targetX] ~= 1 then -- THE MAGIC HAPPENS HERE!
       
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
    if gameState == "menu" then
        drawMenu()
        return
    end
    
    if gameState == "shop" then
        drawShop()
        return
    end
    
    -- Apply screen shake
    love.graphics.push()
    love.graphics.translate(screenShake.x, screenShake.y)
    
    love.graphics.clear(colors.background[1]/255, colors.background[2]/255, colors.background[3]/255)

    -- 1. Draw scenery and items that can be hidden
    -- Map and Grid
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
    -- Traps and Target
    love.graphics.setColor(colors.foreground)
    for _, trap in ipairs(traps) do
        love.graphics.circle("fill", (trap.x - 1) * gridSize + gridSize / 2, (trap.y - 1) * gridSize + gridSize / 2, gridSize / 3 )
    end
    
    -- Draw glowing target with pulsing effect
    local goalX = (goal.x - 1) * gridSize
    local goalY = (goal.y - 1) * gridSize
    
    -- Draw outer glow circles
    local glowIntensity = goalGlow.intensity * 0.8 + 0.2 -- Never fully disappear
    local glowSize = goalGlow.intensity * 15 + 5 -- Pulsing size
    
    -- Multiple glow layers for better effect
    love.graphics.setColor(0, 1, 0, glowIntensity * 0.1)
    love.graphics.circle("fill", goalX + gridSize/2, goalY + gridSize/2, glowSize + 10)
    
    love.graphics.setColor(0, 1, 0, glowIntensity * 0.3)
    love.graphics.circle("fill", goalX + gridSize/2, goalY + gridSize/2, glowSize + 5)
    
    love.graphics.setColor(0, 1, 0, glowIntensity * 0.6)
    love.graphics.circle("fill", goalX + gridSize/2, goalY + gridSize/2, glowSize)
    
    -- Draw the target sprite with varying opacity
    love.graphics.setColor(1, 1, 1, glowIntensity * 0.7 + 0.3)
    love.graphics.draw(sprites.sheet, sprites.target, goalX, goalY)

    for i, ps in ipairs(activeParticles) do
        love.graphics.draw(ps)
    end
    
    -- 2. Apply darkness mask (if necessary)
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

    -- 3. Draw ALWAYS visible elements (on top of darkness)
    -- Batteries
    love.graphics.setColor(1, 1, 1) -- Set white color for sprites
    for i, item in ipairs(batteries) do
        love.graphics.draw(sprites.sheet, sprites.battery, (item.x - 1) * gridSize, (item.y - 1) * gridSize)
    end
    -- Player
    if player.isStuck then
        love.graphics.setColor(colors.player_stuck[1]/255, colors.player_stuck[2]/255, colors.player_stuck[3]/255)
    else
        love.graphics.setColor(1, 1, 1) -- White color for player too
    end
    player.currentAnim:draw(sprites.sheet, (player.x - 1) * gridSize, (player.y - 1) * gridSize)
    
    if game.lightTimer > 0 then
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.setColor(colors.light_timer, colors.light_timer, colors.light_timer)
        local lightText = "Light: " .. string.format("%.1f", game.lightTimer) .. "s"
        love.graphics.printf(lightText, love.graphics.getWidth() - 120, 10, 110, "right")
    end
    -- 4. Draw UI and end game messages
    drawUI()
    if gameState == "won" then
        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.printf("YOU WON!", 0, love.graphics.getHeight() / 2 - 60, love.graphics.getWidth(), "center")
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.printf("Remaining Battery: " .. player.battery, 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
        love.graphics.printf("Total Score: " .. player.score, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.printf("Press R for next level", 0, love.graphics.getHeight() / 2 + 25, love.graphics.getWidth(), "center")
    elseif gameState == "lost" then
        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.printf("BATTERY DEPLETED!", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Press 'R' to restart", 0, love.graphics.getHeight() / 2 + 10, love.graphics.getWidth(), "center")
    
        if game.lightTimer > 0 then
            love.graphics.setColor(1, 1, 0.2)
            local lightText = "Light: " .. string.format("%.1f", game.lightTimer) .. "s"
            love.graphics.printf(lightText, love.graphics.getWidth() / 2 - 75, uiY + 20, 150, "center")
        end
    end
    
    love.graphics.pop() -- Remove screen shake transformation
end

function drawShop()
    love.graphics.clear(colors.foreground[1]/255, colors.foreground[2]/255, colors.foreground[3]/255)

    love.graphics.setColor(colors.background[1]/255, colors.background[2]/255, colors.background[3]/255)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf("UPGRADE SHOP", 0, 40, love.graphics.getWidth(), "center")

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

    love.graphics.printf("Your choice will take you to the next level.", 0, love.graphics.getHeight() - 80, love.graphics.getWidth(), "center")
end

function drawMenu()
    -- Draw background maze
    love.graphics.clear(colors.background[1]/255, colors.background[2]/255, colors.background[3]/255)
    
    -- Draw maze with transparency
    love.graphics.setColor(colors.foreground[1]/255, colors.foreground[2]/255, colors.foreground[3]/255, 0.3)
    for y = 1, gridHeight do
        for x = 1, gridWidth do
            if menuMap[y][x] == 1 then
                love.graphics.rectangle("fill", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
            end
        end
    end
    
    -- Maze grid
    love.graphics.setColor(colors.dark_wall[1]/255, colors.dark_wall[2]/255, colors.dark_wall[3]/255, 0.2)
    for i = 1, gridWidth do
        love.graphics.line(i * gridSize, 0, i * gridSize, gridHeight * gridSize)
    end
    for i = 1, gridHeight do
        love.graphics.line(0, i * gridSize, gridWidth * gridSize, i * gridSize)
    end
    
    -- Dark overlay for better text readability
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Game title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(48))
    love.graphics.printf("WORN OUT", 0, love.graphics.getHeight() / 2 - 150, love.graphics.getWidth(), "center")
    
    -- Subtitle
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Escape the maze before your battery runs out", 0, love.graphics.getHeight() / 2 - 80, love.graphics.getWidth(), "center")
    
    -- Blinking "Press Start" text
    if menu.showText then
        love.graphics.setFont(love.graphics.newFont(24))
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("PRESS SPACE TO START", 0, love.graphics.getHeight() / 2 + 20, love.graphics.getWidth(), "center")
    end
    
    -- Controls
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("ARROWS: Move | SPACE: Break walls", 0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")
    love.graphics.printf("Collect batteries to survive!", 0, love.graphics.getHeight() - 40, love.graphics.getWidth(), "center")

    -- Créditos do autor
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("a game by netorapg", 0, love.graphics.getHeight() - 22, love.graphics.getWidth(), "center")
end

function drawUI()
    local uiY = gridHeight * gridSize + 5

    love.graphics.setColor(colors.foreground)
    love.graphics.rectangle("fill", 0, gridHeight * gridSize, love.graphics.getWidth(), 40)

    -- Battery (reduced)
    love.graphics.setColor(colors.dark_wall[1]/255, colors.dark_wall[2]/255, colors.dark_wall[3]/255)
    local maxBatteryBarWidth = 120 -- Reduced from 200 to 120
    love.graphics.rectangle("fill", 10, uiY, maxBatteryBarWidth, 25) -- Height also reduced

    love.graphics.setColor(0, 1, 0)
    local batteryWidth = (player.battery / player.maxBattery) * maxBatteryBarWidth
    love.graphics.rectangle("fill", 10, uiY, batteryWidth, 25)

    -- Battery text
    love.graphics.setColor(colors.background[1]/255, colors.background[2]/255, colors.background[3]/255)
    love.graphics.setFont(love.graphics.newFont(14)) -- Slightly smaller font
    love.graphics.printf(player.battery .. "/" .. player.maxBattery, 10, uiY + 5, maxBatteryBarWidth, "center")

    love.graphics.printf("Moves: " .. player.moves, 140, uiY + 5, 120, "left")

    -- Score (better aligned)
    love.graphics.printf("Score: " .. player.score, love.graphics.getWidth() - 150, uiY + 5, 140, "right")

    love.graphics.printf("Level: " .. game.level, 140, uiY + 20, 120, "left")

     if player.abilityCooldown > 0 then
        love.graphics.setColor(colors.player_stuck[1]/255, colors.player_stuck[2]/255, colors.player_stuck[3]/255)
        local cooldownText = "Recharging: " .. string.format("%.1f", player.abilityCooldown) .. "s"
        love.graphics.printf(cooldownText, 270, uiY + 5, 180, "left")
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("[Space] Break (" .. abilityCost .. ")", 270, uiY + 5, 180, "left")
    end
end

function generateMenuBackground()
    menuMap = {}
    for y = 1, gridHeight do
        menuMap[y] = {}
        for x = 1, gridWidth do
            menuMap[y][x] = 1
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
            if ny > 1 and ny < gridHeight and nx > 1 and nx < gridWidth and menuMap[ny][nx] == 1 then
                menuMap[ny][nx] = 0
                menuMap[ny - dir[2]/2][nx - dir[1]/2] = 0
                carvePassages(nx, ny)
            end
        end
    end

    local startX, startY = 3, 3
    menuMap[startY][startX] = 0
    carvePassages(startX, startY)
end