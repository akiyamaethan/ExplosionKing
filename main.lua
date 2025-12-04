-- Explosion King - Explosion-Based Movement

--------------------
-- Dependencies --
--------------------
local wf = require 'libraries.windfield.windfield'
local Input = require 'input'

----------------------
-- Physics Objects --
----------------------
local world
local player
local ground
local walls = {}  -- screen boundary walls
local buildingBlocks = {}  -- draggable shapes

-------------------------
-- Player Constants --
-------------------------
local PLAYER_RADIUS = 30
local BLOCK_SIZE = PLAYER_RADIUS * 2  -- roughly player size
local GROUND_HEIGHT = 50

---------------------------
-- Explosion Constants --
---------------------------
local EXPLOSION_RADIUS = PLAYER_RADIUS * 3  -- 3x player radius
local EXPLOSION_FORCE = 1600  -- tuned to launch ~1/3 screen height from ground

---------------------------
-- Drag and Drop State --
---------------------------
local draggedBlock = nil
local dragOffsetX, dragOffsetY = 0, 0
local dragStartX, dragStartY = 0, 0  -- track where mouse press started
local DRAG_THRESHOLD = 5  -- pixels of movement before it's considered a drag
local pointerPressX, pointerPressY = 0, 0  -- for tap detection

-----------------------
-- Selection State --
-----------------------
local selectedBlock = nil

------------------------
-- Inventory System --
------------------------
local inventory = {}  -- stores picked up blocks: {type = "square", size = BLOCK_SIZE}
local pickupButton = nil  -- will hold the pickup button image

----------------------------
-- Inventory UI Constants --
----------------------------
local INVENTORY_SLOT_SIZE = 32
local INVENTORY_SLOT_PADDING = 8
local MAX_VISIBLE_SLOTS = 5

---------------------------
-- Inventory Drag State --
---------------------------
local draggingFromInventory = false
local inventoryDragIndex = nil  -- which slot we're dragging from
local inventoryDragX, inventoryDragY = 0, 0

----------------------
-- Target and Win --
----------------------
local target = {x = 0, y = 0, radius = 40}
local gameWon = false

--------------------
-- Stage System --
--------------------
local currentStage = 1
local stages = {
    {
        name = "Stage 1",
        targetPosition = "top-right",
        blocks = {
            {x = 0.25, y = 50},
            {x = 0.50, y = 50},
            {x = 0.75, y = 50},
        },
    },
    {
        name = "Stage 2",
        targetPosition = "top-left",
        blocks = {
            {x = 0.25, y = 50},
            {x = 0.50, y = 50},
            {x = 0.75, y = 50},
        },
    },
    {
        name = "Stage 3",
        type = "ending",
    },
}

--------------------
-- Save System --
--------------------
local SAVE_FILE = "autosave.json"
local showSaveDetectedScreen = false
local saveExists = false

--------------------
-- Theme System --
--------------------
local THEME_SETTINGS_FILE = "theme_settings.txt"
local currentThemeSetting = "time"  -- "light", "dark", or "time"
local showOptionsScreen = false
local dropdownOpen = false

----------------------------
-- Theme Color Definitions --
----------------------------
local themes = {
    light = {
        sky = {0.5, 0.7, 0.9},
        ground = {0.4, 0.3, 0.2},
        inventoryBg = {1, 1, 1},
        inventorySlot = {0.85, 0.85, 0.85},
        text = {0, 0, 0},
        textLight = {1, 1, 1},
        block = {0, 0, 0},
        blockSelected = {1, 0.85, 0.2},
        player = {0.2, 0.8, 0.2},
        explosionRadius = {1, 0.5, 0, 0.2},
        uiBackground = {0.9, 0.9, 0.9},
        uiBorder = {0.5, 0.5, 0.5},
    },
    dark = {
        sky = {0.1, 0.1, 0.2},
        ground = {0.2, 0.15, 0.1},
        inventoryBg = {0.2, 0.2, 0.25},
        inventorySlot = {0.3, 0.3, 0.35},
        text = {0.9, 0.9, 0.9},
        textLight = {0.9, 0.9, 0.9},
        block = {0.4, 0.4, 0.5},
        blockSelected = {0.6, 0.6, 0.7},
        player = {0.1, 0.6, 0.1},
        explosionRadius = {1, 0.4, 0, 0.3},
        uiBackground = {0.15, 0.15, 0.2},
        uiBorder = {0.4, 0.4, 0.5},
    },
}

--------------------------
-- Theme Helper Functions --
--------------------------

-- returns current theme colors based on setting
local function getCurrentTheme()
    if currentThemeSetting == "light" then
        return themes.light
    elseif currentThemeSetting == "dark" then
        return themes.dark
    else
        -- time-based: day 6am-6pm, night otherwise
        local hour = tonumber(os.date("%H"))
        if hour >= 6 and hour < 18 then
            return themes.light
        else
            return themes.dark
        end
    end
end

local function saveThemeSetting()
    love.filesystem.write(THEME_SETTINGS_FILE, currentThemeSetting)
end

local function loadThemeSetting()
    if love.filesystem.getInfo(THEME_SETTINGS_FILE) then
        local content = love.filesystem.read(THEME_SETTINGS_FILE)
        if content == "light" or content == "dark" or content == "time" then
            currentThemeSetting = content
        end
    end
end

---------------------------
-- Localization System --
---------------------------
local LANGUAGE_SETTINGS_FILE = "language_settings.txt"
local currentLanguage = "en"  -- "en", "zh", or "ar"
local languageDropdownOpen = false

-- pickup button images for each language and theme (loaded in love.load)
local pickupButtons = {
    light = {},
    dark = {},
}

-- fonts for each language (loaded in love.load)
local fonts = {}
local FONT_SIZE = 14

---------------------------
-- Translation Strings --
---------------------------
local translations = {
    en = {
        instructions = "Tap background: explode | R: restart | Drag blocks | Tap to select",
        inventoryEmpty = "Inventory Empty",
        victory = "VICTORY",
        nextStage = "Next Stage",
        conclusiveEnding = "Conclusive Ending",
        restartGame = "Restart Game",
        saveDetected = "Save Detected, Load?",
        options = "Options",
        visualStyle = "Visual Style:",
        language = "Language:",
        light = "Light",
        dark = "Dark",
        timeBased = "Time-Based",
        stage = "Stage",
        english = "English",
        chinese = "Chinese",
        arabic = "Arabic",
    },
    zh = {
        instructions = "点击背景: 爆炸 | R: 重启 | 拖动方块 | 点击选择",
        inventoryEmpty = "背包为空",
        victory = "胜利",
        nextStage = "下一关",
        conclusiveEnding = "游戏结束",
        restartGame = "重新开始",
        saveDetected = "检测到存档，是否加载？",
        options = "选项",
        visualStyle = "视觉风格：",
        language = "语言：",
        light = "明亮",
        dark = "暗黑",
        timeBased = "跟随时间",
        stage = "关卡",
        english = "英语",
        chinese = "中文",
        arabic = "阿拉伯语",
    },
    ar = {
        instructions = "اضغط على الخلفية: انفجار | R: إعادة | اسحب الكتل | اضغط للتحديد",
        inventoryEmpty = "المخزون فارغ",
        victory = "فوز",
        nextStage = "المرحلة التالية",
        conclusiveEnding = "النهاية",
        restartGame = "إعادة اللعبة",
        saveDetected = "تم اكتشاف حفظ، هل تريد التحميل؟",
        options = "خيارات",
        visualStyle = "النمط المرئي:",
        language = "اللغة:",
        light = "فاتح",
        dark = "داكن",
        timeBased = "حسب الوقت",
        stage = "مرحلة",
        english = "الإنجليزية",
        chinese = "الصينية",
        arabic = "العربية",
    },
}

-------------------------------
-- Localization Helpers --
-------------------------------

local function getText(key)
    local lang = translations[currentLanguage]
    if lang and lang[key] then
        return lang[key]
    end
    -- fallback to english
    return translations.en[key] or key
end

local function getCurrentPickupButton()
    local theme = getCurrentTheme()
    local themeKey = (theme == themes.dark) and "dark" or "light"
    local themeButtons = pickupButtons[themeKey]
    return themeButtons[currentLanguage] or themeButtons.en
end

local function getCurrentFont()
    return fonts[currentLanguage] or fonts.en
end

local function applyCurrentFont()
    local font = getCurrentFont()
    if font then
        love.graphics.setFont(font)
    end
end

local function getLanguageDisplayName(lang)
    if lang == "en" then return getText("english")
    elseif lang == "zh" then return getText("chinese")
    elseif lang == "ar" then return getText("arabic")
    end
    return lang
end

local function saveLanguageSetting()
    love.filesystem.write(LANGUAGE_SETTINGS_FILE, currentLanguage)
end

local function loadLanguageSetting()
    if love.filesystem.getInfo(LANGUAGE_SETTINGS_FILE) then
        local content = love.filesystem.read(LANGUAGE_SETTINGS_FILE)
        if content == "en" or content == "zh" or content == "ar" then
            currentLanguage = content
        end
    end
end

----------------------------
-- Save System Helpers --
----------------------------

-- simple json-like serialization for save data
local function serializeValue(val)
    local t = type(val)
    if t == "number" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        local parts = {}
        -- Check if array-like
        local isArray = #val > 0 or next(val) == nil
        if isArray then
            for _, v in ipairs(val) do
                table.insert(parts, serializeValue(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, string.format("%q:%s", k, serializeValue(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function saveGame()
    local blockData = {}
    for _, block in ipairs(buildingBlocks) do
        local bx, by = block:getPosition()
        table.insert(blockData, {x = bx, y = by})
    end

    local px, py = player:getPosition()
    local vx, vy = player:getLinearVelocity()

    local saveData = {
        currentStage = currentStage,
        inventory = inventory,
        playerX = px,
        playerY = py,
        playerVX = vx,
        playerVY = vy,
        blocks = blockData,
        gameWon = gameWon,
    }

    local json = serializeValue(saveData)
    local success, message = love.filesystem.write(SAVE_FILE, json)
    if success then
        print("Game saved!")
    else
        print("Failed to save: " .. (message or "unknown error"))
    end
    return success
end

-- basic json parser for our save format
local function parseValue(str, pos)
    pos = pos or 1
    -- Skip whitespace
    while pos <= #str and str:sub(pos, pos):match("%s") do
        pos = pos + 1
    end

    local char = str:sub(pos, pos)

    if char == "{" then
        -- Object
        local obj = {}
        pos = pos + 1
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
            if str:sub(pos, pos) == "}" then return obj, pos + 1 end
            if str:sub(pos, pos) == "," then pos = pos + 1 end
            while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
            if str:sub(pos, pos) == "}" then return obj, pos + 1 end
            -- Parse key
            local key, val
            if str:sub(pos, pos) == '"' then
                local endQ = str:find('"', pos + 1)
                key = str:sub(pos + 1, endQ - 1)
                pos = endQ + 1
            end
            while pos <= #str and str:sub(pos, pos):match("[%s:]") do pos = pos + 1 end
            val, pos = parseValue(str, pos)
            obj[key] = val
        end
        return obj, pos
    elseif char == "[" then
        -- Array
        local arr = {}
        pos = pos + 1
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
            if str:sub(pos, pos) == "]" then return arr, pos + 1 end
            if str:sub(pos, pos) == "," then pos = pos + 1 end
            while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
            if str:sub(pos, pos) == "]" then return arr, pos + 1 end
            local val
            val, pos = parseValue(str, pos)
            table.insert(arr, val)
        end
        return arr, pos
    elseif char == '"' then
        -- String
        local endQ = str:find('"', pos + 1)
        local val = str:sub(pos + 1, endQ - 1)
        -- Unescape
        val = val:gsub('\\"', '"'):gsub("\\\\", "\\")
        return val, endQ + 1
    elseif str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    else
        -- Number
        local numStr = str:match("^%-?%d+%.?%d*", pos)
        if numStr then
            return tonumber(numStr), pos + #numStr
        end
    end
    return nil, pos
end

local function hasSaveFile()
    return love.filesystem.getInfo(SAVE_FILE) ~= nil
end

local function loadGameState()
    if not hasSaveFile() then
        return nil
    end

    local content, err = love.filesystem.read(SAVE_FILE)
    if not content then
        print("Failed to read save: " .. (err or "unknown error"))
        return nil
    end

    local data = parseValue(content)
    return data
end

local function deleteSaveFile()
    if hasSaveFile() then
        love.filesystem.remove(SAVE_FILE)
        print("Save file deleted")
    end
end

---------------------------------
-- Forward Declarations --
---------------------------------
-- these functions have interdependencies so we declare them here
local loadStage
local applySaveData

applySaveData = function(data)
    if not data then return false end

    -- load the stage first (sets up target position)
    currentStage = data.currentStage or 1
    loadStage(currentStage)

    inventory = data.inventory or {}

    if data.playerX and data.playerY then
        player:setPosition(data.playerX, data.playerY)
    end
    if data.playerVX and data.playerVY then
        player:setLinearVelocity(data.playerVX, data.playerVY)
    end

    -- recreate blocks at saved positions
    for _, block in ipairs(buildingBlocks) do
        block:destroy()
    end
    buildingBlocks = {}

    if data.blocks then
        for _, blockData in ipairs(data.blocks) do
            local halfSize = BLOCK_SIZE / 2
            local collider = world:newRectangleCollider(
                blockData.x - halfSize, blockData.y - halfSize,
                BLOCK_SIZE, BLOCK_SIZE
            )
            collider:setType('static')
            collider:setCollisionClass('Block')
            table.insert(buildingBlocks, collider)
        end
    end

    gameWon = data.gameWon or false

    print("Game loaded!")
    return true
end

--------------------------
-- Physics Helpers --
--------------------------

local function getObjectsInRadius(cx, cy, radius)
    local results = {}
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local groundTop = windowHeight - GROUND_HEIGHT

    if cy + radius >= groundTop then
        table.insert(results, {x = cx, y = groundTop})
    end

    if cx - radius <= 0 then
        table.insert(results, {x = 0, y = cy})
    end
    if cx + radius >= windowWidth then
        table.insert(results, {x = windowWidth, y = cy})
    end
    if cy - radius <= 0 then
        table.insert(results, {x = cx, y = 0})
    end

    for _, block in ipairs(buildingBlocks) do
        local bx, by = block:getPosition()
        local dist = math.sqrt((cx - bx)^2 + (cy - by)^2)

        if dist - BLOCK_SIZE/2 <= radius then
            table.insert(results, {x = bx, y = by})
        end
    end

    return results
end

local function isPointInBlock(block, px, py)
    local bx, by = block:getPosition()
    local halfSize = BLOCK_SIZE / 2
    return px >= bx - halfSize and px <= bx + halfSize and
           py >= by - halfSize and py <= by + halfSize
end

local function overlapsPlayer(x, y)
    local px, py = player:getPosition()
    local dist = math.sqrt((x - px)^2 + (y - py)^2)
    return dist < PLAYER_RADIUS + BLOCK_SIZE / 2 + 10
end

local function isPointInPickupButton(px, py)
    if not selectedBlock then return false end
    local currentButton = getCurrentPickupButton()
    if not currentButton then return false end

    local bx, by = selectedBlock:getPosition()
    local buttonWidth = currentButton:getWidth()
    local buttonHeight = currentButton:getHeight()
    local buttonX = bx - buttonWidth / 2
    local buttonY = by - buttonHeight / 2

    return px >= buttonX and px <= buttonX + buttonWidth and
           py >= buttonY and py <= buttonY + buttonHeight
end

--------------------------
-- Inventory Helpers --
--------------------------

local function getInventorySlotBounds(index)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local inventoryY = windowHeight - GROUND_HEIGHT + 5
    local inventoryHeight = GROUND_HEIGHT - 5

    local slotCount = math.min(#inventory, MAX_VISIBLE_SLOTS)
    local totalWidth = slotCount * INVENTORY_SLOT_SIZE + (slotCount - 1) * INVENTORY_SLOT_PADDING
    local startX = (windowWidth - totalWidth) / 2

    local slotX = startX + (index - 1) * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_PADDING)
    local slotY = inventoryY + (inventoryHeight - INVENTORY_SLOT_SIZE) / 2

    return slotX, slotY, INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE
end

local function getInventorySlotAtPoint(px, py)
    if #inventory == 0 then return nil end

    for i = 1, math.min(#inventory, MAX_VISIBLE_SLOTS) do
        local slotX, slotY, slotW, slotH = getInventorySlotBounds(i)
        if px >= slotX and px <= slotX + slotW and
           py >= slotY and py <= slotY + slotH then
            return i
        end
    end
    return nil
end

local function spawnBlockFromInventory(index, x, y)
    if not inventory[index] then return false end

    local windowWidth, windowHeight = love.graphics.getDimensions()
    local halfSize = BLOCK_SIZE / 2

    -- clamp position to valid area
    x = math.max(halfSize, math.min(windowWidth - halfSize, x))
    y = math.max(halfSize, math.min(windowHeight - GROUND_HEIGHT - halfSize, y))

    -- push away from player if overlapping
    if overlapsPlayer(x, y) then
        local px, py = player:getPosition()
        local dx, dy = x - px, y - py
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            dx, dy = dx / dist, dy / dist
        else
            dx, dy = 0, -1
        end
        local pushDist = PLAYER_RADIUS + halfSize + 15
        x, y = px + dx * pushDist, py + dy * pushDist
    end

    local collider = world:newRectangleCollider(x - halfSize, y - halfSize, BLOCK_SIZE, BLOCK_SIZE)
    collider:setType('static')
    collider:setCollisionClass('Block')
    table.insert(buildingBlocks, collider)

    table.remove(inventory, index)

    print("Block spawned from inventory! Remaining: " .. #inventory)
    return true
end

-----------------------
-- LÖVE Callbacks --
-----------------------

function love.load()
    loadThemeSetting()
    loadLanguageSetting()

    -- load pickup button images for all languages and themes
    pickupButtons.light.en = love.graphics.newImage("pickupButton.png")
    pickupButtons.light.zh = love.graphics.newImage("pickupButtonChinese.png")
    pickupButtons.light.ar = love.graphics.newImage("pickupButtonArabic.png")
    pickupButtons.dark.en = love.graphics.newImage("pickupButton_dark.png")
    pickupButtons.dark.zh = love.graphics.newImage("pickupButtonChinese_dark.png")
    pickupButtons.dark.ar = love.graphics.newImage("pickupButtonArabic_dark.png")
    pickupButton = pickupButtons.light.en

    -- load fonts for all languages
    fonts.en = love.graphics.newFont(FONT_SIZE)
    fonts.zh = love.graphics.newFont("fonts/NotoSansSC-Regular.ttf", FONT_SIZE)
    fonts.ar = love.graphics.newFont("fonts/NotoSansArabic-Regular.ttf", FONT_SIZE)

    applyCurrentFont()

    -- create physics world with gravity
    world = wf.newWorld(0, 500, true)

    -- define collision classes
    world:addCollisionClass('Ground')
    world:addCollisionClass('Wall')
    world:addCollisionClass('Player')
    world:addCollisionClass('Block')
    world:addCollisionClass('BlockDragging', {ignores = {'Player'}})

    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- create ground
    ground = world:newRectangleCollider(0, windowHeight - GROUND_HEIGHT, windowWidth, GROUND_HEIGHT)
    ground:setType('static')
    ground:setCollisionClass('Ground')

    -- create invisible walls to keep player on screen
    local wallThickness = 20

    walls.left = world:newRectangleCollider(-wallThickness, 0, wallThickness, windowHeight)
    walls.left:setType('static')
    walls.left:setCollisionClass('Wall')

    walls.right = world:newRectangleCollider(windowWidth, 0, wallThickness, windowHeight)
    walls.right:setType('static')
    walls.right:setCollisionClass('Wall')

    walls.top = world:newRectangleCollider(0, -wallThickness, windowWidth, wallThickness)
    walls.top:setType('static')
    walls.top:setCollisionClass('Wall')

    -- create player
    player = world:newCircleCollider(windowWidth / 2, windowHeight - GROUND_HEIGHT - PLAYER_RADIUS, PLAYER_RADIUS)
    player:setType('dynamic')
    player:setRestitution(0.3)
    player:setCollisionClass('Player')

    -- check for save file before loading stage
    if hasSaveFile() then
        saveExists = true
        showSaveDetectedScreen = true
    else
        loadStage(currentStage)
    end

    -- register unified input callbacks
    Input.onPointerPressed = function(x, y) handlePointerPressed(x, y) end
    Input.onPointerReleased = function(x, y) handlePointerReleased(x, y) end
end

------------------------
-- Stage Management --
------------------------

-- uses forward declaration from above
loadStage = function(stageIndex)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local stage = stages[stageIndex]

    -- handle ending stage
    if stage.type == "ending" then
        gameWon = false
        selectedBlock = nil
        draggedBlock = nil

        for _, block in ipairs(buildingBlocks) do
            block:destroy()
        end
        buildingBlocks = {}

        deleteSaveFile()

        print("Loaded Ending Stage")
        currentStage = stageIndex
        return true
    end

    if not stage then
        print("No more stages! You completed the game!")
        return false
    end

    -- reset game state (but NOT inventory)
    gameWon = false
    selectedBlock = nil
    draggedBlock = nil
    draggingFromInventory = false
    inventoryDragIndex = nil

    for _, block in ipairs(buildingBlocks) do
        block:destroy()
    end
    buildingBlocks = {}

    -- create blocks for this stage
    for _, blockDef in ipairs(stage.blocks) do
        local x = windowWidth * blockDef.x
        local y = blockDef.y
        local collider = world:newRectangleCollider(x - BLOCK_SIZE/2, y - BLOCK_SIZE/2, BLOCK_SIZE, BLOCK_SIZE)
        collider:setType('static')
        collider:setCollisionClass('Block')
        table.insert(buildingBlocks, collider)
    end

    -- position target based on stage config
    if stage.targetPosition == "top-right" then
        target.x = windowWidth - target.radius - 20
        target.y = target.radius + 20
    elseif stage.targetPosition == "top-left" then
        target.x = target.radius + 20
        target.y = target.radius + 20
    end

    -- reset player position and velocity
    player:setPosition(windowWidth / 2, windowHeight - GROUND_HEIGHT - PLAYER_RADIUS)
    player:setLinearVelocity(0, 0)
    player:setAngularVelocity(0)

    currentStage = stageIndex
    print("Loaded " .. stage.name)
    return true
end

function love.update(dt)
    if showSaveDetectedScreen then return end
    if showOptionsScreen then return end
    if gameWon then return end

    world:update(dt)

    -- check for victory
    local px, py = player:getPosition()
    local dist = math.sqrt((px - target.x)^2 + (py - target.y)^2)
    if dist < target.radius + PLAYER_RADIUS then
        gameWon = true
        return
    end

    -- update dragged block position
    if draggedBlock then
        local mx, my = Input.getPosition()
        local newX, newY = mx + dragOffsetX, my + dragOffsetY

        local windowWidth, windowHeight = love.graphics.getDimensions()
        local halfSize = BLOCK_SIZE / 2
        newX = math.max(halfSize, math.min(windowWidth - halfSize, newX))
        newY = math.max(halfSize, math.min(windowHeight - GROUND_HEIGHT - halfSize, newY))

        draggedBlock:setPosition(newX, newY)
    end

    Input.updateFromMouse()
end

--------------------------
-- Explosion System --
--------------------------

local function performExplosion()
    if gameWon then return end
    local px, py = player:getPosition()

    local nearbyObjects = getObjectsInRadius(px, py, EXPLOSION_RADIUS)

    -- calculate cumulative force direction based on nearby objects
    local forceX, forceY = 0, 0
    local objectsInRange = 0

    for _, obj in ipairs(nearbyObjects) do
        local ox, oy = obj.x, obj.y
        local dx = px - ox
        local dy = py - oy
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance > 0 then
            dx = dx / distance
            dy = dy / distance

            -- closer objects contribute more force
            local strength = 1 - (distance / EXPLOSION_RADIUS)
            strength = math.max(0, strength)

            forceX = forceX + dx * strength
            forceY = forceY + dy * strength
            objectsInRange = objectsInRange + 1
        else
            forceY = forceY - 1
            objectsInRange = objectsInRange + 1
        end
    end

    if objectsInRange > 0 then
        local magnitude = math.sqrt(forceX * forceX + forceY * forceY)

        if magnitude > 0 then
            forceX = forceX / magnitude
            forceY = forceY / magnitude

            local finalForce = EXPLOSION_FORCE * math.min(objectsInRange, 3)
            player:applyLinearImpulse(forceX * finalForce, forceY * finalForce)
        end
    end

    saveGame()
end

--------------------
-- UI Helpers --
--------------------

local function getSaveYButtonBounds()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local btnW = 80
    local btnH = 50
    local spacing = 40
    local btnY = windowHeight / 2 + 20
    local btnX = windowWidth / 2 - btnW - spacing / 2
    return btnX, btnY, btnW, btnH
end

local function getSaveNButtonBounds()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local btnW = 80
    local btnH = 50
    local spacing = 40
    local btnY = windowHeight / 2 + 20
    local btnX = windowWidth / 2 + spacing / 2
    return btnX, btnY, btnW, btnH
end

local function isPointInSaveYButton(px, py)
    local bx, by, bw, bh = getSaveYButtonBounds()
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

local function isPointInSaveNButton(px, py)
    local bx, by, bw, bh = getSaveNButtonBounds()
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

local function getOptionsButtonBounds()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local text = getText("options")
    local padding = 10
    local btnW = font:getWidth(text) + padding * 2
    local btnH = font:getHeight() + padding
    local btnX = windowWidth - btnW - 10
    local btnY = windowHeight - GROUND_HEIGHT - btnH - 10
    return btnX, btnY, btnW, btnH
end

local function isPointInOptionsButton(px, py)
    local bx, by, bw, bh = getOptionsButtonBounds()
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

local function getOptionsXButtonBounds()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local btnSize = 40
    local panelW = 300
    local panelH = 250
    local panelX = windowWidth / 2 - panelW / 2
    local panelY = windowHeight / 2 - panelH / 2
    return panelX + panelW - btnSize - 10, panelY + panelH - btnSize - 10, btnSize, btnSize
end

local function isPointInOptionsXButton(px, py)
    local bx, by, bw, bh = getOptionsXButtonBounds()
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

local function getThemeDropdownBounds()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local panelW = 300
    local panelH = 250
    local panelX = windowWidth / 2 - panelW / 2
    local panelY = windowHeight / 2 - panelH / 2
    local dropW = 150
    local dropH = 30
    local dropX = panelX + panelW / 2 - dropW / 2
    local dropY = panelY + 80
    return dropX, dropY, dropW, dropH
end

local function getThemeDropdownOptionBounds(index)
    local dropX, dropY, dropW, dropH = getThemeDropdownBounds()
    return dropX, dropY + dropH * index, dropW, dropH
end

local function isPointInThemeDropdown(px, py)
    local bx, by, bw, bh = getThemeDropdownBounds()
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

local function getDropdownOptionAtPoint(px, py)
    if not dropdownOpen then return nil end
    local options = {"light", "dark", "time"}
    for i, _ in ipairs(options) do
        local ox, oy, ow, oh = getThemeDropdownOptionBounds(i)
        if px >= ox and px <= ox + ow and py >= oy and py <= oy + oh then
            return i
        end
    end
    return nil
end

local function getThemeDisplayName(setting)
    if setting == "light" then return getText("light")
    elseif setting == "dark" then return getText("dark")
    else return getText("timeBased")
    end
end

local function getLanguageDropdownBounds()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local panelW = 300
    local panelH = 250
    local panelX = windowWidth / 2 - panelW / 2
    local panelY = windowHeight / 2 - panelH / 2
    local dropW = 150
    local dropH = 30
    local dropX = panelX + panelW / 2 - dropW / 2
    local dropY = panelY + 155
    return dropX, dropY, dropW, dropH
end

local function getLanguageDropdownOptionBounds(index)
    local dropX, dropY, dropW, dropH = getLanguageDropdownBounds()
    return dropX, dropY + dropH * index, dropW, dropH
end

local function isPointInLanguageDropdown(px, py)
    local bx, by, bw, bh = getLanguageDropdownBounds()
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

local function getLanguageDropdownOptionAtPoint(px, py)
    if not languageDropdownOpen then return nil end
    local options = {"en", "zh", "ar"}
    for i, _ in ipairs(options) do
        local ox, oy, ow, oh = getLanguageDropdownOptionBounds(i)
        if px >= ox and px <= ox + ow and py >= oy and py <= oy + oh then
            return i
        end
    end
    return nil
end

function love.draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Apply the current language font
    applyCurrentFont()

    -- Draw save detection screen if active (blocks all other drawing)
    if showSaveDetectedScreen then
        -- Dark background
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

        -- Centered text
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.getFont()
        local text = getText("saveDetected")
        local textWidth = font:getWidth(text)
        love.graphics.print(text, windowWidth / 2 - textWidth / 2, windowHeight / 2 - 40)

        -- Y button (green)
        local yX, yY, yW, yH = getSaveYButtonBounds()
        love.graphics.setColor(0.2, 0.7, 0.2)
        love.graphics.rectangle("fill", yX, yY, yW, yH, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", yX, yY, yW, yH, 8, 8)
        local yText = "Y"
        local yTextWidth = font:getWidth(yText)
        love.graphics.print(yText, yX + yW / 2 - yTextWidth / 2, yY + yH / 2 - font:getHeight() / 2)

        -- N button (red)
        local nX, nY, nW, nH = getSaveNButtonBounds()
        love.graphics.setColor(0.7, 0.2, 0.2)
        love.graphics.rectangle("fill", nX, nY, nW, nH, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", nX, nY, nW, nH, 8, 8)
        local nText = "N"
        local nTextWidth = font:getWidth(nText)
        love.graphics.print(nText, nX + nW / 2 - nTextWidth / 2, nY + nH / 2 - font:getHeight() / 2)

        return  -- Don't draw anything else
    end

    -- Get current theme colors
    local theme = getCurrentTheme()

    -- Draw options screen if active (blocks all other drawing)
    if showOptionsScreen then
        -- Semi-transparent dark overlay
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

        -- Options panel
        local panelW = 300
        local panelH = 250  -- Increased for language dropdown
        local panelX = windowWidth / 2 - panelW / 2
        local panelY = windowHeight / 2 - panelH / 2

        -- Panel background
        love.graphics.setColor(theme.uiBackground[1], theme.uiBackground[2], theme.uiBackground[3])
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
        love.graphics.setColor(theme.uiBorder[1], theme.uiBorder[2], theme.uiBorder[3])
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)

        -- Title (localized)
        local font = love.graphics.getFont()
        love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
        local title = getText("options")
        local titleWidth = font:getWidth(title)
        love.graphics.print(title, panelX + panelW / 2 - titleWidth / 2, panelY + 20)

        -- Helper function to draw Visual Style dropdown
        local function drawThemeDropdown(drawOptions)
            -- Visual Style label (localized)
            love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
            local label = getText("visualStyle")
            love.graphics.print(label, panelX + panelW / 2 - font:getWidth(label) / 2, panelY + 55)

            -- Theme Dropdown header
            local dropX, dropY, dropW, dropH = getThemeDropdownBounds()
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", dropX, dropY, dropW, dropH, 4, 4)
            love.graphics.setColor(theme.uiBorder[1], theme.uiBorder[2], theme.uiBorder[3])
            love.graphics.rectangle("line", dropX, dropY, dropW, dropH, 4, 4)

            -- Current theme selection text
            love.graphics.setColor(0, 0, 0)
            local selText = getThemeDisplayName(currentThemeSetting)
            love.graphics.print(selText, dropX + 10, dropY + dropH / 2 - font:getHeight() / 2)

            -- Theme dropdown arrow
            love.graphics.polygon("fill",
                dropX + dropW - 20, dropY + dropH / 2 - 4,
                dropX + dropW - 10, dropY + dropH / 2 - 4,
                dropX + dropW - 15, dropY + dropH / 2 + 4
            )

            -- Theme dropdown options (if open and requested)
            if drawOptions and dropdownOpen then
                local options = {"light", "dark", "time"}
                for i, opt in ipairs(options) do
                    local ox, oy, ow, oh = getThemeDropdownOptionBounds(i)
                    if opt == currentThemeSetting then
                        love.graphics.setColor(0.8, 0.9, 1)
                    else
                        love.graphics.setColor(1, 1, 1)
                    end
                    love.graphics.rectangle("fill", ox, oy, ow, oh)
                    love.graphics.setColor(theme.uiBorder[1], theme.uiBorder[2], theme.uiBorder[3])
                    love.graphics.rectangle("line", ox, oy, ow, oh)
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.print(getThemeDisplayName(opt), ox + 10, oy + oh / 2 - font:getHeight() / 2)
                end
            end
        end

        -- Helper function to draw Language dropdown
        local function drawLanguageDropdown(drawOptions)
            -- Language label (localized)
            love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
            local langLabel = getText("language")
            love.graphics.print(langLabel, panelX + panelW / 2 - font:getWidth(langLabel) / 2, panelY + 130)

            -- Language Dropdown header
            local langDropX, langDropY, langDropW, langDropH = getLanguageDropdownBounds()
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", langDropX, langDropY, langDropW, langDropH, 4, 4)
            love.graphics.setColor(theme.uiBorder[1], theme.uiBorder[2], theme.uiBorder[3])
            love.graphics.rectangle("line", langDropX, langDropY, langDropW, langDropH, 4, 4)

            -- Current language selection text
            love.graphics.setColor(0, 0, 0)
            local langSelText = getLanguageDisplayName(currentLanguage)
            love.graphics.print(langSelText, langDropX + 10, langDropY + langDropH / 2 - font:getHeight() / 2)

            -- Language dropdown arrow
            love.graphics.polygon("fill",
                langDropX + langDropW - 20, langDropY + langDropH / 2 - 4,
                langDropX + langDropW - 10, langDropY + langDropH / 2 - 4,
                langDropX + langDropW - 15, langDropY + langDropH / 2 + 4
            )

            -- Language dropdown options (if open and requested)
            if drawOptions and languageDropdownOpen then
                local langOptions = {"en", "zh", "ar"}
                for i, lang in ipairs(langOptions) do
                    local ox, oy, ow, oh = getLanguageDropdownOptionBounds(i)
                    if lang == currentLanguage then
                        love.graphics.setColor(0.8, 0.9, 1)
                    else
                        love.graphics.setColor(1, 1, 1)
                    end
                    love.graphics.rectangle("fill", ox, oy, ow, oh)
                    love.graphics.setColor(theme.uiBorder[1], theme.uiBorder[2], theme.uiBorder[3])
                    love.graphics.rectangle("line", ox, oy, ow, oh)
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.print(getLanguageDisplayName(lang), ox + 10, oy + oh / 2 - font:getHeight() / 2)
                end
            end
        end

        -- Draw dropdowns in correct order (active dropdown drawn last, on top)
        if dropdownOpen then
            -- Theme dropdown is open, draw language first, then theme on top
            drawLanguageDropdown(false)
            drawThemeDropdown(true)
        elseif languageDropdownOpen then
            -- Language dropdown is open, draw theme first, then language on top
            drawThemeDropdown(false)
            drawLanguageDropdown(true)
        else
            -- Neither open, draw in normal order
            drawThemeDropdown(false)
            drawLanguageDropdown(false)
        end

        -- X button (red, bottom right)
        local xX, xY, xW, xH = getOptionsXButtonBounds()
        love.graphics.setColor(0.8, 0.2, 0.2)
        love.graphics.rectangle("fill", xX, xY, xW, xH, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", xX, xY, xW, xH, 6, 6)
        -- Draw X
        love.graphics.setLineWidth(3)
        love.graphics.line(xX + 10, xY + 10, xX + xW - 10, xY + xH - 10)
        love.graphics.line(xX + xW - 10, xY + 10, xX + 10, xY + xH - 10)
        love.graphics.setLineWidth(1)

        return  -- Don't draw anything else
    end

    -- Draw sky background
    love.graphics.setBackgroundColor(theme.sky[1], theme.sky[2], theme.sky[3])

    -- Draw target (bullseye pattern)
    love.graphics.setColor(1, 0, 0)  -- Red outer
    love.graphics.circle("fill", target.x, target.y, target.radius)
    love.graphics.setColor(1, 1, 1)  -- White middle
    love.graphics.circle("fill", target.x, target.y, target.radius * 0.66)
    love.graphics.setColor(1, 0, 0)  -- Red inner
    love.graphics.circle("fill", target.x, target.y, target.radius * 0.33)

    -- Draw ground (themed)
    love.graphics.setColor(theme.ground[1], theme.ground[2], theme.ground[3])
    love.graphics.rectangle("fill", 0, windowHeight - GROUND_HEIGHT, windowWidth, GROUND_HEIGHT)

    -- Draw inventory UI over ground (leaving a few pixels of ground visible above)
    local inventoryTopMargin = 5  -- Pixels of ground visible above inventory
    local inventoryY = windowHeight - GROUND_HEIGHT + inventoryTopMargin
    local inventoryHeight = GROUND_HEIGHT - inventoryTopMargin

    -- Inventory background (themed)
    love.graphics.setColor(theme.inventoryBg[1], theme.inventoryBg[2], theme.inventoryBg[3])
    love.graphics.rectangle("fill", 0, inventoryY, windowWidth, inventoryHeight)

    -- Draw inventory slots
    if #inventory > 0 then
        for i = 1, math.min(#inventory, MAX_VISIBLE_SLOTS) do
            local slotX, slotY, slotW, slotH = getInventorySlotBounds(i)

            -- Skip drawing the slot being dragged (it will be drawn at mouse position)
            if not (draggingFromInventory and inventoryDragIndex == i) then
                -- Slot background (themed)
                love.graphics.setColor(theme.inventorySlot[1], theme.inventorySlot[2], theme.inventorySlot[3])
                love.graphics.rectangle("fill", slotX, slotY, slotW, slotH)

                -- Block icon inside slot (themed)
                local iconPadding = 4
                love.graphics.setColor(theme.block[1], theme.block[2], theme.block[3])
                love.graphics.rectangle("fill", slotX + iconPadding, slotY + iconPadding,
                                        slotW - iconPadding * 2, slotH - iconPadding * 2)

                -- Slot border (themed)
                love.graphics.setColor(theme.uiBorder[1], theme.uiBorder[2], theme.uiBorder[3])
                love.graphics.rectangle("line", slotX, slotY, slotW, slotH)
            end
        end

        -- Show overflow indicator if more than MAX_VISIBLE_SLOTS
        if #inventory > MAX_VISIBLE_SLOTS then
            local font = love.graphics.getFont()
            local overflowText = "+" .. (#inventory - MAX_VISIBLE_SLOTS)
            local lastSlotX, lastSlotY = getInventorySlotBounds(MAX_VISIBLE_SLOTS)
            love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
            love.graphics.print(overflowText, lastSlotX + INVENTORY_SLOT_SIZE + 8,
                               lastSlotY + (INVENTORY_SLOT_SIZE - font:getHeight()) / 2)
        end
    else
        -- Empty inventory message
        local font = love.graphics.getFont()
        local emptyText = getText("inventoryEmpty")
        local textWidth = font:getWidth(emptyText)
        love.graphics.setColor(theme.uiBorder[1], theme.uiBorder[2], theme.uiBorder[3])
        love.graphics.print(emptyText, (windowWidth - textWidth) / 2,
                           inventoryY + (inventoryHeight - font:getHeight()) / 2)
    end

    -- Draw building blocks (highlight selected block, themed)
    for _, block in ipairs(buildingBlocks) do
        local bx, by = block:getPosition()
        local halfSize = BLOCK_SIZE / 2

        -- Use different color for selected block
        if block == selectedBlock then
            -- Highlighted color (themed)
            love.graphics.setColor(theme.blockSelected[1], theme.blockSelected[2], theme.blockSelected[3])
        else
            -- Normal color (themed)
            love.graphics.setColor(theme.block[1], theme.block[2], theme.block[3])
        end

        love.graphics.rectangle("fill", bx - halfSize, by - halfSize, BLOCK_SIZE, BLOCK_SIZE)
    end

    -- Draw pickup button centered on selected block
    if selectedBlock then
        local bx, by = selectedBlock:getPosition()
        local currentButton = getCurrentPickupButton()

        -- Center the button on the block
        local buttonWidth = currentButton:getWidth()
        local buttonHeight = currentButton:getHeight()
        local buttonX = bx - buttonWidth / 2
        local buttonY = by - buttonHeight / 2

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(currentButton, buttonX, buttonY)
    end

    -- Draw player (themed)
    love.graphics.setColor(theme.player[1], theme.player[2], theme.player[3])
    local px, py = player:getPosition()
    love.graphics.circle("fill", px, py, PLAYER_RADIUS)

    -- Draw explosion radius indicator (themed)
    love.graphics.setColor(theme.explosionRadius[1], theme.explosionRadius[2], theme.explosionRadius[3], theme.explosionRadius[4])
    love.graphics.circle("line", px, py, EXPLOSION_RADIUS)

    -- Draw instructions and stage indicator (themed text)
    love.graphics.setColor(theme.textLight[1], theme.textLight[2], theme.textLight[3])
    love.graphics.print(getText("instructions"), 10, 10)

    -- Draw current stage name
    local stageName = stages[currentStage] and stages[currentStage].name or "Unknown"
    local font = love.graphics.getFont()
    local stageText = stageName
    local stageTextWidth = font:getWidth(stageText)
    love.graphics.print(stageText, windowWidth - stageTextWidth - 10, 10)

    -- Draw Options button (bottom right, above inventory)
    local optX, optY, optW, optH = getOptionsButtonBounds()
    love.graphics.setColor(theme.uiBackground[1], theme.uiBackground[2], theme.uiBackground[3])
    love.graphics.rectangle("fill", optX, optY, optW, optH, 4, 4)
    love.graphics.setColor(theme.uiBorder[1], theme.uiBorder[2], theme.uiBorder[3])
    love.graphics.rectangle("line", optX, optY, optW, optH, 4, 4)
    love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
    love.graphics.print(getText("options"), optX + 10, optY + optH / 2 - font:getHeight() / 2)

    -- Highlight dragged block
    if draggedBlock then
        love.graphics.setColor(1, 1, 0, 0.3)
        local bx, by = draggedBlock:getPosition()
        love.graphics.circle("line", bx, by, BLOCK_SIZE / 2 + 5)
    end

    -- Draw ghost block preview when dragging from inventory
    if draggingFromInventory and inventoryDragIndex then
        local mx, my = Input.getPosition()
        local halfSize = BLOCK_SIZE / 2
        local inventoryY = windowHeight - GROUND_HEIGHT + 5

        -- Clamp preview position to valid spawn area
        local previewX = math.max(halfSize, math.min(windowWidth - halfSize, mx))
        local previewY = math.max(halfSize, math.min(inventoryY - halfSize, my))

        -- Ghost block (semi-transparent)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", previewX - halfSize, previewY - halfSize, BLOCK_SIZE, BLOCK_SIZE)

        -- Highlight circle around ghost
        love.graphics.setColor(1, 1, 0, 0.4)
        love.graphics.circle("line", previewX, previewY, halfSize + 5)

        -- Show "invalid" indicator if over inventory area
        if my >= inventoryY then
            love.graphics.setColor(1, 0.3, 0.3, 0.7)
            love.graphics.setLineWidth(3)
            love.graphics.line(previewX - 15, previewY - 15, previewX + 15, previewY + 15)
            love.graphics.line(previewX + 15, previewY - 15, previewX - 15, previewY + 15)
            love.graphics.setLineWidth(1)
        end
    end

    -- Victory screen
    if gameWon then
        -- Semi-transparent overlay
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

        -- Victory text
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.getFont()
        local text = getText("victory")
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(text, windowWidth/2 - textWidth/2, windowHeight/2 - textHeight/2 - 30)

        -- Next Stage button
        local buttonText = getText("nextStage")
        local buttonTextWidth = font:getWidth(buttonText)
        local buttonPadding = 16
        local buttonWidth = buttonTextWidth + buttonPadding * 2
        local buttonHeight = textHeight + buttonPadding
        local buttonX = windowWidth/2 - buttonWidth/2
        local buttonY = windowHeight/2 + 20

        -- Button background
        love.graphics.setColor(0.2, 0.6, 0.3)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 4, 4)

        -- Button border
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 4, 4)

        -- Button text
        love.graphics.print(buttonText, buttonX + buttonPadding, buttonY + buttonPadding/2)
    end
        -- SPECIAL ENDING STAGE SCREEN
    if stages[currentStage] and stages[currentStage].type == "ending" then
        -- Black background
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

        -- Title text
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.getFont()
        local text = getText("conclusiveEnding")
        local textWidth = font:getWidth(text)
        love.graphics.print(text, windowWidth/2 - textWidth/2, windowHeight/2 - 80)

        -- Restart button
        local buttonText = getText("restartGame")
        local btnW = font:getWidth(buttonText) + 32
        local btnH = font:getHeight() + 20
        local btnX = windowWidth/2 - btnW/2
        local btnY = windowHeight/2

        -- Button background
        love.graphics.setColor(0.3, 0.6, 1)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6)

        -- Button border
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 6)

        -- Button label
        love.graphics.print(buttonText, btnX + 16, btnY + 10)
    end
end

-- mouse input callbacks
function love.mousepressed(x, y, button)
    Input.handleMousePressed(x, y, button)
end

function love.mousereleased(x, y, button)
    Input.handleMouseReleased(x, y, button)
end

-- touch input callbacks
function love.touchpressed(id, x, y, dx, dy, pressure)
    Input.handleTouchPressed(id, x, y)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    Input.handleTouchReleased(id, x, y)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    Input.handleTouchMoved(id, x, y)
end

--------------------------
-- Scene Management --
--------------------------

local function restartScene()
    inventory = {}
    deleteSaveFile()
    loadStage(currentStage)
    print("Scene restarted!")
end

local function nextStage()
    local nextIndex = currentStage + 1
    currentStage = nextIndex
    loadStage(nextIndex)
end

-- keyboard input
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        restartScene()
    end
end

local function getNextStageButtonBounds()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local buttonText = getText("nextStage")
    local buttonTextWidth = font:getWidth(buttonText)
    local textHeight = font:getHeight()
    local buttonPadding = 16
    local buttonWidth = buttonTextWidth + buttonPadding * 2
    local buttonHeight = textHeight + buttonPadding
    local buttonX = windowWidth/2 - buttonWidth/2
    local buttonY = windowHeight/2 + 20

    return buttonX, buttonY, buttonWidth, buttonHeight
end

local function isPointInNextStageButton(px, py)
    if not gameWon then return false end
    local bx, by, bw, bh = getNextStageButtonBounds()
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

local function isPointInRestartButton(px, py)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local font = love.graphics.getFont()

    local buttonText = getText("restartGame")
    local btnW = font:getWidth(buttonText) + 32
    local btnH = font:getHeight() + 20
    local btnX = windowWidth/2 - btnW/2
    local btnY = windowHeight/2

    return px >= btnX and px <= btnX + btnW and
           py >= btnY and py <= btnY + btnH
end

-- checks if point is on empty space (for explosion triggering)
local function isEmptySpace(px, py)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local inventoryY = windowHeight - GROUND_HEIGHT + 5

    if py >= inventoryY then return false end

    local targetDist = math.sqrt((px - target.x)^2 + (py - target.y)^2)
    if targetDist < target.radius then return false end

    local playerX, playerY = player:getPosition()
    local playerDist = math.sqrt((px - playerX)^2 + (py - playerY)^2)
    if playerDist < PLAYER_RADIUS then return false end

    for _, block in ipairs(buildingBlocks) do
        if isPointInBlock(block, px, py) then return false end
    end

    if isPointInPickupButton(px, py) then return false end
    if gameWon and isPointInNextStageButton(px, py) then return false end

    if stages[currentStage] and stages[currentStage].type == "ending" then
        if isPointInRestartButton(px, py) then return false end
    end

    if isPointInOptionsButton(px, py) then return false end

    return true
end

--------------------------
-- Input Handlers --
--------------------------

local function pickupSelectedBlock()
    if not selectedBlock or gameWon then return end

    for i, block in ipairs(buildingBlocks) do
        if block == selectedBlock then
            table.insert(inventory, {
                type = "square",
                size = BLOCK_SIZE,
            })

            selectedBlock:destroy()
            table.remove(buildingBlocks, i)
            selectedBlock = nil

            print("Block picked up! Inventory count: " .. #inventory)
            break
        end
    end
end

local function handlePointerPressed(x, y)
    -- handle save detection screen
    if showSaveDetectedScreen then
        if isPointInSaveYButton(x, y) then
            local saveData = loadGameState()
            if saveData then
                showSaveDetectedScreen = false
                applySaveData(saveData)
            end
        elseif isPointInSaveNButton(x, y) then
            showSaveDetectedScreen = false
            deleteSaveFile()
            loadStage(1)
        end
        return
    end

    -- handle options screen
    if showOptionsScreen then
        if isPointInOptionsXButton(x, y) then
            showOptionsScreen = false
            dropdownOpen = false
            languageDropdownOpen = false
            return
        end

        if dropdownOpen then
            local optIndex = getDropdownOptionAtPoint(x, y)
            if optIndex then
                local options = {"light", "dark", "time"}
                currentThemeSetting = options[optIndex]
                saveThemeSetting()
                dropdownOpen = false
                return
            end
        end

        if languageDropdownOpen then
            local langOptIndex = getLanguageDropdownOptionAtPoint(x, y)
            if langOptIndex then
                local langOptions = {"en", "zh", "ar"}
                currentLanguage = langOptions[langOptIndex]
                saveLanguageSetting()
                applyCurrentFont()
                languageDropdownOpen = false
                return
            end
        end

        if isPointInThemeDropdown(x, y) then
            dropdownOpen = not dropdownOpen
            languageDropdownOpen = false
            return
        end

        if isPointInLanguageDropdown(x, y) then
            languageDropdownOpen = not languageDropdownOpen
            dropdownOpen = false
            return
        end

        dropdownOpen = false
        languageDropdownOpen = false
        return
    end

    if isPointInOptionsButton(x, y) then
        showOptionsScreen = true
        dropdownOpen = false
        return
    end

    -- ending stage restart
    if stages[currentStage] and stages[currentStage].type == "ending" then
        if isPointInRestartButton(x, y) then
            inventory = {}
            deleteSaveFile()
            loadStage(1)
        end
        return
    end

    -- victory screen next stage
    if gameWon then
        if isPointInNextStageButton(x, y) then
            nextStage()
        end
        return
    end

    -- pickup button takes priority
    if isPointInPickupButton(x, y) then
        pickupSelectedBlock()
        return
    end

    -- inventory slot click
    local slotIndex = getInventorySlotAtPoint(x, y)
    if slotIndex then
        draggingFromInventory = true
        inventoryDragIndex = slotIndex
        inventoryDragX, inventoryDragY = x, y
        return
    end

    dragStartX, dragStartY = x, y
    pointerPressX, pointerPressY = x, y

    -- check if clicking on a block
    for _, block in ipairs(buildingBlocks) do
        if isPointInBlock(block, x, y) then
            draggedBlock = block
            local bx, by = block:getPosition()
            dragOffsetX = bx - x
            dragOffsetY = by - y
            block:setCollisionClass('BlockDragging')
            break
        end
    end

    if not draggedBlock then
        selectedBlock = nil
    end
end

local function handlePointerReleased(x, y)
    -- handle inventory drag release
    if draggingFromInventory and inventoryDragIndex then
        local windowHeight = love.graphics.getHeight()
        local inventoryY = windowHeight - GROUND_HEIGHT + 5

        if y < inventoryY then
            spawnBlockFromInventory(inventoryDragIndex, x, y)
        end

        draggingFromInventory = false
        inventoryDragIndex = nil
        return
    end

    -- handle block drag release
    if draggedBlock then
        local dragDist = math.sqrt((x - dragStartX)^2 + (y - dragStartY)^2)

        -- tap to select
        if dragDist < DRAG_THRESHOLD then
            selectedBlock = draggedBlock
            draggedBlock:setCollisionClass('Block')
            draggedBlock = nil
            return
        end

        -- push away from player if overlapping
        local bx, by = draggedBlock:getPosition()
        if overlapsPlayer(bx, by) then
            local px, py = player:getPosition()
            local dx, dy = bx - px, by - py
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                dx, dy = dx / dist, dy / dist
            else
                dx, dy = 0, -1
            end
            local pushDist = PLAYER_RADIUS + BLOCK_SIZE / 2 + 15
            draggedBlock:setPosition(px + dx * pushDist, py + dy * pushDist)
        end
        draggedBlock:setCollisionClass('Block')
        draggedBlock = nil
        return
    end

    -- tap empty space to trigger explosion
    local tapDist = math.sqrt((x - pointerPressX)^2 + (y - pointerPressY)^2)
    if tapDist < DRAG_THRESHOLD and isEmptySpace(x, y) then
        if not gameWon then
            performExplosion()
        end
    end
end

local function getInventory()
    return inventory
end

local function getInventoryCount()
    return #inventory
end
