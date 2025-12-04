-- Explosion King - Explosion-Based Movement

local wf = require 'libraries.windfield.windfield'
local Input = require 'input'

local world
local player
local ground
local walls = {}  -- Screen boundary walls
local buildingBlocks = {}  -- Draggable shapes

-- Constants
local PLAYER_RADIUS = 30
local BLOCK_SIZE = PLAYER_RADIUS * 2  -- Roughly player size
local GROUND_HEIGHT = 50

-- Explosion constants
local EXPLOSION_RADIUS = PLAYER_RADIUS * 3  -- 3x player radius
local EXPLOSION_FORCE = 1600  -- Base force, tuned to launch ~1/3 screen height from ground

-- Drag and drop state
local draggedBlock = nil
local dragOffsetX, dragOffsetY = 0, 0
local dragStartX, dragStartY = 0, 0  -- Track where mouse press started
local DRAG_THRESHOLD = 5  -- Pixels of movement before it's considered a drag
local pointerPressX, pointerPressY = 0, 0  -- Where pointer press started (for tap detection)

-- Selection state
local selectedBlock = nil

-- Inventory system
local inventory = {}  -- Stores picked up blocks: {type = "square", size = BLOCK_SIZE}
local pickupButton = nil  -- Will hold the pickup button image

-- Inventory UI constants
local INVENTORY_SLOT_SIZE = 32  -- Size of each inventory slot
local INVENTORY_SLOT_PADDING = 8  -- Padding between slots
local MAX_VISIBLE_SLOTS = 5  -- Maximum slots shown in UI

-- Inventory drag state
local draggingFromInventory = false
local inventoryDragIndex = nil  -- Which slot we're dragging from
local inventoryDragX, inventoryDragY = 0, 0  -- Current drag position

-- Target state
local target = {x = 0, y = 0, radius = 40}
local gameWon = false

-- Stage system
local currentStage = 1
local stages = {
    {
        name = "Stage 1",
        targetPosition = "top-right",  -- Target in top right corner
        blocks = {  -- Block positions as fractions of screen width
            {x = 0.25, y = 50},
            {x = 0.50, y = 50},
            {x = 0.75, y = 50}
        }
    },
    {
        name = "Stage 2",
        targetPosition = "top-left",  -- Target in top left corner
        blocks = {
            {x = 0.25, y = 50},
            {x = 0.50, y = 50},
            {x = 0.75, y = 50}
        }
    },
    {
        name = "Stage 3",
        type = "ending"  -- special stage type
    }
}

-- Get positions of objects within explosion radius
function getObjectsInRadius(cx, cy, radius)
    local results = {}
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local groundTop = windowHeight - GROUND_HEIGHT

    -- Check ground
    if cy + radius >= groundTop then
        table.insert(results, {x = cx, y = groundTop})
    end

    -- Check walls
    if cx - radius <= 0 then
        table.insert(results, {x = 0, y = cy})
    end
    if cx + radius >= windowWidth then
        table.insert(results, {x = windowWidth, y = cy})
    end
    if cy - radius <= 0 then
        table.insert(results, {x = cx, y = 0})
    end

    -- Check building blocks
    for _, block in ipairs(buildingBlocks) do
        local bx, by = block:getPosition()
        local dist = math.sqrt((cx - bx)^2 + (cy - by)^2)

        if dist - BLOCK_SIZE/2 <= radius then
            table.insert(results, {x = bx, y = by})
        end
    end

    return results
end

-- Check if a point is inside a block (for drag detection)
function isPointInBlock(block, px, py)
    local bx, by = block:getPosition()
    local halfSize = BLOCK_SIZE / 2
    return px >= bx - halfSize and px <= bx + halfSize and
           py >= by - halfSize and py <= by + halfSize
end

-- Check if position overlaps with player
function overlapsPlayer(x, y)
    local px, py = player:getPosition()
    local dist = math.sqrt((x - px)^2 + (y - py)^2)
    return dist < PLAYER_RADIUS + BLOCK_SIZE / 2 + 10  -- 10px buffer
end

-- Check if a point is inside the pickup button (when a block is selected)
function isPointInPickupButton(px, py)
    if not selectedBlock or not pickupButton then return false end

    local bx, by = selectedBlock:getPosition()
    local buttonWidth = pickupButton:getWidth()
    local buttonHeight = pickupButton:getHeight()
    local buttonX = bx - buttonWidth / 2
    local buttonY = by - buttonHeight / 2

    return px >= buttonX and px <= buttonX + buttonWidth and
           py >= buttonY and py <= buttonY + buttonHeight
end

-- Get the bounding box for an inventory slot at given index (1-based)
function getInventorySlotBounds(index)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local inventoryY = windowHeight - GROUND_HEIGHT + 5  -- Same as inventoryTopMargin
    local inventoryHeight = GROUND_HEIGHT - 5

    local slotCount = math.min(#inventory, MAX_VISIBLE_SLOTS)
    local totalWidth = slotCount * INVENTORY_SLOT_SIZE + (slotCount - 1) * INVENTORY_SLOT_PADDING
    local startX = (windowWidth - totalWidth) / 2

    local slotX = startX + (index - 1) * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_PADDING)
    local slotY = inventoryY + (inventoryHeight - INVENTORY_SLOT_SIZE) / 2

    return slotX, slotY, INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE
end

-- Check if a point is inside an inventory slot, returns slot index or nil
function getInventorySlotAtPoint(px, py)
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

-- Spawn a block from inventory at the given position
function spawnBlockFromInventory(index, x, y)
    if not inventory[index] then return false end

    local windowWidth, windowHeight = love.graphics.getDimensions()
    local halfSize = BLOCK_SIZE / 2

    -- Clamp position to valid area (not below ground, not off screen)
    x = math.max(halfSize, math.min(windowWidth - halfSize, x))
    y = math.max(halfSize, math.min(windowHeight - GROUND_HEIGHT - halfSize, y))

    -- Don't spawn if overlapping player
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

    -- Create the physics collider
    local collider = world:newRectangleCollider(x - halfSize, y - halfSize, BLOCK_SIZE, BLOCK_SIZE)
    collider:setType('static')
    collider:setCollisionClass('Block')
    table.insert(buildingBlocks, collider)

    -- Remove from inventory
    table.remove(inventory, index)

    print("Block spawned from inventory! Remaining: " .. #inventory)
    return true
end

function love.load()
    -- Load pickup button image
    pickupButton = love.graphics.newImage("pickupButton.png")

    -- Create physics world with gravity using Windfield
    world = wf.newWorld(0, 500, true)

    -- Define collision classes for different object types
    world:addCollisionClass('Ground')
    world:addCollisionClass('Wall')
    world:addCollisionClass('Player')
    world:addCollisionClass('Block')
    world:addCollisionClass('BlockDragging', {ignores = {'Player'}})  -- No collision while dragging

    -- Get window dimensions
    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Create ground (static body)
    ground = world:newRectangleCollider(0, windowHeight - GROUND_HEIGHT, windowWidth, GROUND_HEIGHT)
    ground:setType('static')
    ground:setCollisionClass('Ground')

    -- Create invisible walls to keep player on screen
    local wallThickness = 20

    -- Left wall
    walls.left = world:newRectangleCollider(-wallThickness, 0, wallThickness, windowHeight)
    walls.left:setType('static')
    walls.left:setCollisionClass('Wall')

    -- Right wall
    walls.right = world:newRectangleCollider(windowWidth, 0, wallThickness, windowHeight)
    walls.right:setType('static')
    walls.right:setCollisionClass('Wall')

    -- Top wall (ceiling)
    walls.top = world:newRectangleCollider(0, -wallThickness, windowWidth, wallThickness)
    walls.top:setType('static')
    walls.top:setCollisionClass('Wall')

    -- Create player (dynamic body with gravity)
    player = world:newCircleCollider(windowWidth / 2, windowHeight - GROUND_HEIGHT - PLAYER_RADIUS, PLAYER_RADIUS)
    player:setType('dynamic')
    player:setRestitution(0.3)
    player:setCollisionClass('Player')

    -- Load the first stage
    loadStage(currentStage)

    -- Register unified input callbacks
    Input.onPointerPressed = function(x, y) handlePointerPressed(x, y) end
    Input.onPointerReleased = function(x, y) handlePointerReleased(x, y) end
end

-- Load a stage by index (keeps inventory intact)
function loadStage(stageIndex)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local stage = stages[stageIndex]

        -- Handle Ending Stage
    if stage.type == "ending" then
        gameWon = false
        selectedBlock = nil
        draggedBlock = nil

        -- Destroy existing blocks
        for _, block in ipairs(buildingBlocks) do
            block:destroy()
        end
        buildingBlocks = {}

        print("Loaded Ending Stage")
        currentStage = stageIndex
        return true
    end

    if not stage then
        print("No more stages! You completed the game!")
        return false
    end

    -- Reset game state (but NOT inventory)
    gameWon = false
    selectedBlock = nil
    draggedBlock = nil
    draggingFromInventory = false
    inventoryDragIndex = nil

    -- Destroy existing blocks
    for _, block in ipairs(buildingBlocks) do
        block:destroy()
    end
    buildingBlocks = {}

    -- Create blocks for this stage
    for _, blockDef in ipairs(stage.blocks) do
        local x = windowWidth * blockDef.x
        local y = blockDef.y
        local collider = world:newRectangleCollider(x - BLOCK_SIZE/2, y - BLOCK_SIZE/2, BLOCK_SIZE, BLOCK_SIZE)
        collider:setType('static')
        collider:setCollisionClass('Block')
        table.insert(buildingBlocks, collider)
    end

    -- Position target based on stage config
    if stage.targetPosition == "top-right" then
        target.x = windowWidth - target.radius - 20
        target.y = target.radius + 20
    elseif stage.targetPosition == "top-left" then
        target.x = target.radius + 20
        target.y = target.radius + 20
    end

    -- Reset player position and velocity
    player:setPosition(windowWidth / 2, windowHeight - GROUND_HEIGHT - PLAYER_RADIUS)
    player:setLinearVelocity(0, 0)
    player:setAngularVelocity(0)

    currentStage = stageIndex
    print("Loaded " .. stage.name)
    return true
end

function love.update(dt)
    -- Don't update physics if game is won
    if gameWon then return end

    world:update(dt)

    -- Check for victory (player overlaps target)
    local px, py = player:getPosition()
    local dist = math.sqrt((px - target.x)^2 + (py - target.y)^2)
    if dist < target.radius + PLAYER_RADIUS then
        gameWon = true
        return
    end

    -- Update dragged block position using Input abstraction
    if draggedBlock then
        local mx, my = Input.getPosition()
        local newX, newY = mx + dragOffsetX, my + dragOffsetY

        -- Keep block on screen
        local windowWidth, windowHeight = love.graphics.getDimensions()
        local halfSize = BLOCK_SIZE / 2
        newX = math.max(halfSize, math.min(windowWidth - halfSize, newX))
        newY = math.max(halfSize, math.min(windowHeight - GROUND_HEIGHT - halfSize, newY))

        draggedBlock:setPosition(newX, newY)
    end

    -- Update Input module for mouse position (when not touching)
    Input.updateFromMouse()
end

-- Perform explosion - query nearby objects and calculate repulsion force
function performExplosion()
    if gameWon then return end
    local px, py = player:getPosition()

    local nearbyObjects = getObjectsInRadius(px, py, EXPLOSION_RADIUS)

    -- Calculate cumulative force direction based on nearby objects
    local forceX, forceY = 0, 0
    local objectsInRange = 0

    for _, obj in ipairs(nearbyObjects) do
        local ox, oy = obj.x, obj.y

        -- Calculate direction FROM the object TO the player (repulsion)
        local dx = px - ox
        local dy = py - oy

        -- Calculate distance
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance > 0 then
            -- Normalize direction
            dx = dx / distance
            dy = dy / distance

            -- Closer objects contribute more force (inverse relationship)
            local strength = 1 - (distance / EXPLOSION_RADIUS)
            strength = math.max(0, strength)

            forceX = forceX + dx * strength
            forceY = forceY + dy * strength
            objectsInRange = objectsInRange + 1
        else
            -- Object is exactly at player position - push up
            forceY = forceY - 1
            objectsInRange = objectsInRange + 1
        end
    end

    -- Only apply force if there are objects to push off of
    if objectsInRange > 0 then
        local magnitude = math.sqrt(forceX * forceX + forceY * forceY)

        if magnitude > 0 then
            forceX = forceX / magnitude
            forceY = forceY / magnitude

            local finalForce = EXPLOSION_FORCE * math.min(objectsInRange, 3)
            player:applyLinearImpulse(forceX * finalForce, forceY * finalForce)
        end
    end
end

function love.draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Draw sky background
    love.graphics.setBackgroundColor(0.5, 0.7, 0.9)

    -- Draw target (bullseye pattern)
    love.graphics.setColor(1, 0, 0)  -- Red outer
    love.graphics.circle("fill", target.x, target.y, target.radius)
    love.graphics.setColor(1, 1, 1)  -- White middle
    love.graphics.circle("fill", target.x, target.y, target.radius * 0.66)
    love.graphics.setColor(1, 0, 0)  -- Red inner
    love.graphics.circle("fill", target.x, target.y, target.radius * 0.33)

    -- Draw ground (brown)
    love.graphics.setColor(0.4, 0.3, 0.2)
    love.graphics.rectangle("fill", 0, windowHeight - GROUND_HEIGHT, windowWidth, GROUND_HEIGHT)

    -- Draw inventory UI over ground (leaving a few pixels of ground visible above)
    local inventoryTopMargin = 5  -- Pixels of ground visible above inventory
    local inventoryY = windowHeight - GROUND_HEIGHT + inventoryTopMargin
    local inventoryHeight = GROUND_HEIGHT - inventoryTopMargin

    -- White background
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", 0, inventoryY, windowWidth, inventoryHeight)

    -- Draw inventory slots
    if #inventory > 0 then
        for i = 1, math.min(#inventory, MAX_VISIBLE_SLOTS) do
            local slotX, slotY, slotW, slotH = getInventorySlotBounds(i)

            -- Skip drawing the slot being dragged (it will be drawn at mouse position)
            if not (draggingFromInventory and inventoryDragIndex == i) then
                -- Slot background (light gray)
                love.graphics.setColor(0.85, 0.85, 0.85)
                love.graphics.rectangle("fill", slotX, slotY, slotW, slotH)

                -- Block icon inside slot (black square, slightly smaller)
                local iconPadding = 4
                love.graphics.setColor(0, 0, 0)
                love.graphics.rectangle("fill", slotX + iconPadding, slotY + iconPadding,
                                        slotW - iconPadding * 2, slotH - iconPadding * 2)

                -- Slot border
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.rectangle("line", slotX, slotY, slotW, slotH)
            end
        end

        -- Show overflow indicator if more than MAX_VISIBLE_SLOTS
        if #inventory > MAX_VISIBLE_SLOTS then
            local font = love.graphics.getFont()
            local overflowText = "+" .. (#inventory - MAX_VISIBLE_SLOTS)
            local lastSlotX, lastSlotY = getInventorySlotBounds(MAX_VISIBLE_SLOTS)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print(overflowText, lastSlotX + INVENTORY_SLOT_SIZE + 8,
                               lastSlotY + (INVENTORY_SLOT_SIZE - font:getHeight()) / 2)
        end
    else
        -- Empty inventory message
        local font = love.graphics.getFont()
        local emptyText = "Inventory Empty"
        local textWidth = font:getWidth(emptyText)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print(emptyText, (windowWidth - textWidth) / 2,
                           inventoryY + (inventoryHeight - font:getHeight()) / 2)
    end

    -- Draw building blocks (highlight selected block)
    for _, block in ipairs(buildingBlocks) do
        local bx, by = block:getPosition()
        local halfSize = BLOCK_SIZE / 2

        -- Use different color for selected block
        if block == selectedBlock then
            -- Highlighted color (bright golden yellow)
            love.graphics.setColor(1, 0.85, 0.2)
        else
            -- Normal color (black)
            love.graphics.setColor(0, 0, 0)
        end

        love.graphics.rectangle("fill", bx - halfSize, by - halfSize, BLOCK_SIZE, BLOCK_SIZE)
    end

    -- Draw pickup button centered on selected block
    if selectedBlock then
        local bx, by = selectedBlock:getPosition()

        -- Center the button on the block
        local buttonWidth = pickupButton:getWidth()
        local buttonHeight = pickupButton:getHeight()
        local buttonX = bx - buttonWidth / 2
        local buttonY = by - buttonHeight / 2

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(pickupButton, buttonX, buttonY)
    end

    -- Draw player (green)
    love.graphics.setColor(0.2, 0.8, 0.2)
    local px, py = player:getPosition()
    love.graphics.circle("fill", px, py, PLAYER_RADIUS)

    -- Draw explosion radius indicator (subtle)
    love.graphics.setColor(1, 0.5, 0, 0.2)
    love.graphics.circle("line", px, py, EXPLOSION_RADIUS)

    -- Draw instructions and stage indicator
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tap background: explode | R: restart | Drag blocks | Tap to select", 10, 10)

    -- Draw current stage name
    local stageName = stages[currentStage] and stages[currentStage].name or "Unknown"
    local font = love.graphics.getFont()
    local stageText = stageName
    local stageTextWidth = font:getWidth(stageText)
    love.graphics.print(stageText, windowWidth - stageTextWidth - 10, 10)

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
        local text = "VICTORY"
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(text, windowWidth/2 - textWidth/2, windowHeight/2 - textHeight/2 - 30)

        -- Next Stage button
        local buttonText = "Next Stage"
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
        local text = "Conclusive Ending"
        local textWidth = font:getWidth(text)
        love.graphics.print(text, windowWidth/2 - textWidth/2, windowHeight/2 - 80)

        -- Restart button
        local buttonText = "Restart Game"
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

-- Mouse input callbacks (delegate to Input abstraction)
function love.mousepressed(x, y, button)
    Input.handleMousePressed(x, y, button)
end

function love.mousereleased(x, y, button)
    Input.handleMouseReleased(x, y, button)
end

-- Touch input callbacks (delegate to Input abstraction)
function love.touchpressed(id, x, y, dx, dy, pressure)
    Input.handleTouchPressed(id, x, y)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    Input.handleTouchReleased(id, x, y)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    Input.handleTouchMoved(id, x, y)
end

-- Keyboard input (R for debug restart only, ESC to quit)
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        restartScene()
    end
end

-- Restart the current stage (clears inventory)
function restartScene()
    -- Clear inventory on restart
    inventory = {}
    -- Reload current stage
    loadStage(currentStage)
    print("Scene restarted!")
end

-- Advance to the next stage (keeps inventory)
function nextStage()
    local nextIndex = currentStage + 1
    currentStage = nextIndex
    loadStage(nextIndex)
end

-- Get the Next Stage button bounds (for hit detection)
function getNextStageButtonBounds()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local buttonText = "Next Stage"
    local buttonTextWidth = font:getWidth(buttonText)
    local textHeight = font:getHeight()
    local buttonPadding = 16
    local buttonWidth = buttonTextWidth + buttonPadding * 2
    local buttonHeight = textHeight + buttonPadding
    local buttonX = windowWidth/2 - buttonWidth/2
    local buttonY = windowHeight/2 + 20

    return buttonX, buttonY, buttonWidth, buttonHeight
end

-- Check if a point is inside the Next Stage button
function isPointInNextStageButton(px, py)
    if not gameWon then return false end
    local bx, by, bw, bh = getNextStageButtonBounds()
    return px >= bx and px <= bx + bw and py >= by and py <= by + bh
end

function isPointInRestartButton(px, py)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local font = love.graphics.getFont()

    local buttonText = "Restart Game"
    local btnW = font:getWidth(buttonText) + 32
    local btnH = font:getHeight() + 20
    local btnX = windowWidth/2 - btnW/2
    local btnY = windowHeight/2

    return px >= btnX and px <= btnX + btnW and
           py >= btnY and py <= btnY + btnH
end

-- Check if a point is on empty space (not on any interactive element)
-- Used to trigger explosion when tapping background
function isEmptySpace(px, py)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local inventoryY = windowHeight - GROUND_HEIGHT + 5

    -- Over inventory area
    if py >= inventoryY then return false end

    -- Over target
    local targetDist = math.sqrt((px - target.x)^2 + (py - target.y)^2)
    if targetDist < target.radius then return false end

    -- Over player
    local playerX, playerY = player:getPosition()
    local playerDist = math.sqrt((px - playerX)^2 + (py - playerY)^2)
    if playerDist < PLAYER_RADIUS then return false end

    -- Over any block
    for _, block in ipairs(buildingBlocks) do
        if isPointInBlock(block, px, py) then return false end
    end

    -- Over pickup button
    if isPointInPickupButton(px, py) then return false end

    -- Over Next Stage button
    if gameWon and isPointInNextStageButton(px, py) then return false end

    -- Over Restart button (ending stage)
    if stages[currentStage] and stages[currentStage].type == "ending" then
        if isPointInRestartButton(px, py) then return false end
    end

    return true
end

-- Unified pointer pressed handler (called by Input abstraction)
function handlePointerPressed(x, y)
    -- Check for ending stage restart button
    if stages[currentStage] and stages[currentStage].type == "ending" then
        if isPointInRestartButton(x, y) then
            inventory = {}
            loadStage(1)
        end
        return
    end

    -- Check for Next Stage button click on victory screen
    if gameWon then
        if isPointInNextStageButton(x, y) then
            nextStage()
        end
        return
    end

    -- First, check if clicking on the pickup button (takes priority)
    if isPointInPickupButton(x, y) then
        pickupSelectedBlock()
        return
    end

    -- Check if clicking on an inventory slot (starts inventory drag)
    local slotIndex = getInventorySlotAtPoint(x, y)
    if slotIndex then
        draggingFromInventory = true
        inventoryDragIndex = slotIndex
        inventoryDragX, inventoryDragY = x, y
        return
    end

    -- Record start position for click vs drag detection
    dragStartX, dragStartY = x, y
    pointerPressX, pointerPressY = x, y

    -- Check if clicking on a building block
    for _, block in ipairs(buildingBlocks) do
        if isPointInBlock(block, x, y) then
            draggedBlock = block
            local bx, by = block:getPosition()
            dragOffsetX = bx - x
            dragOffsetY = by - y
            -- Disable collision with player while dragging
            block:setCollisionClass('BlockDragging')
            break
        end
    end

    -- If clicked outside any block, deselect current selection
    if not draggedBlock then
        selectedBlock = nil
    end
end

-- Unified pointer released handler (called by Input abstraction)
function handlePointerReleased(x, y)
    -- Handle inventory drag release
    if draggingFromInventory and inventoryDragIndex then
        local windowHeight = love.graphics.getHeight()
        local inventoryY = windowHeight - GROUND_HEIGHT + 5

        -- Only spawn if released above the inventory area (in the game world)
        if y < inventoryY then
            spawnBlockFromInventory(inventoryDragIndex, x, y)
        end

        -- Reset inventory drag state
        draggingFromInventory = false
        inventoryDragIndex = nil
        return
    end

    -- Handle world block drag release
    if draggedBlock then
        -- Calculate how far the pointer moved during this press
        local dragDist = math.sqrt((x - dragStartX)^2 + (y - dragStartY)^2)

        -- If pointer barely moved, treat as a tap (select the block)
        if dragDist < DRAG_THRESHOLD then
            -- Select this block
            selectedBlock = draggedBlock
            -- Re-enable collision since we didn't actually drag
            draggedBlock:setCollisionClass('Block')
            draggedBlock = nil
            return
        end

        -- Otherwise, it was a drag - handle as before
        local bx, by = draggedBlock:getPosition()
        if overlapsPlayer(bx, by) then
            -- Push block away from player
            local px, py = player:getPosition()
            local dx, dy = bx - px, by - py
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                dx, dy = dx / dist, dy / dist
            else
                dx, dy = 0, -1  -- Default to pushing up
            end
            local pushDist = PLAYER_RADIUS + BLOCK_SIZE / 2 + 15
            draggedBlock:setPosition(px + dx * pushDist, py + dy * pushDist)
        end
        -- Re-enable collision with player
        draggedBlock:setCollisionClass('Block')
        draggedBlock = nil
        return
    end

    -- Check for empty space tap -> trigger explosion
    local tapDist = math.sqrt((x - pointerPressX)^2 + (y - pointerPressY)^2)
    if tapDist < DRAG_THRESHOLD and isEmptySpace(x, y) then
        if not gameWon then
            performExplosion()
        end
    end
end

-- Pick up the selected block and add it to inventory
function pickupSelectedBlock()
    if not selectedBlock or gameWon then return end

    -- Find and remove the block from buildingBlocks array
    for i, block in ipairs(buildingBlocks) do
        if block == selectedBlock then
            -- Add to inventory (store block properties for later use)
            table.insert(inventory, {
                type = "square",
                size = BLOCK_SIZE
            })

            -- Remove physics body from the world
            selectedBlock:destroy()

            -- Remove from the blocks table
            table.remove(buildingBlocks, i)

            -- Clear selection
            selectedBlock = nil

            -- Debug output (can be removed later)
            print("Block picked up! Inventory count: " .. #inventory)
            break
        end
    end
end

-- Get the current inventory (for UI or other systems)
function getInventory()
    return inventory
end

-- Get count of items in inventory
function getInventoryCount()
    return #inventory
end
