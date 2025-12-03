-- Explosion King - Explosion-Based Movement

local wf = require 'libraries.windfield.windfield'

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

-- Target state
local target = {x = 0, y = 0, radius = 40}
local gameWon = false

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

function love.load()
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

    -- Create 3 squares centered along the top of the screen
    local topY = 50  -- Near top of screen
    local spacing = windowWidth / 4  -- Divide screen into 4 parts, place at 1/4, 2/4, 3/4

    for i = 1, 3 do
        local x = spacing * i
        local collider = world:newRectangleCollider(x - BLOCK_SIZE/2, topY - BLOCK_SIZE/2, BLOCK_SIZE, BLOCK_SIZE)
        collider:setType('static')
        collider:setCollisionClass('Block')
        table.insert(buildingBlocks, collider)
    end

    -- Position target in top right corner
    target.x = windowWidth - target.radius - 20
    target.y = target.radius + 20
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

    -- Update dragged block position
    if draggedBlock then
        local mx, my = love.mouse.getPosition()
        local newX, newY = mx + dragOffsetX, my + dragOffsetY

        -- Keep block on screen
        local windowWidth, windowHeight = love.graphics.getDimensions()
        local halfSize = BLOCK_SIZE / 2
        newX = math.max(halfSize, math.min(windowWidth - halfSize, newX))
        newY = math.max(halfSize, math.min(windowHeight - GROUND_HEIGHT - halfSize, newY))

        draggedBlock:setPosition(newX, newY)
    end
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

    -- Draw building blocks (black squares)
    love.graphics.setColor(0, 0, 0)
    for _, block in ipairs(buildingBlocks) do
        local bx, by = block:getPosition()
        local halfSize = BLOCK_SIZE / 2
        love.graphics.rectangle("fill", bx - halfSize, by - halfSize, BLOCK_SIZE, BLOCK_SIZE)
    end

    -- Draw player (green)
    love.graphics.setColor(0.2, 0.8, 0.2)
    local px, py = player:getPosition()
    love.graphics.circle("fill", px, py, PLAYER_RADIUS)

    -- Draw explosion radius indicator (subtle)
    love.graphics.setColor(1, 0.5, 0, 0.2)
    love.graphics.circle("line", px, py, EXPLOSION_RADIUS)

    -- Draw instructions
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("SPACE to explode | Drag shapes to build platforms", 10, 10)

    -- Highlight dragged block
    if draggedBlock then
        love.graphics.setColor(1, 1, 0, 0.3)
        local bx, by = draggedBlock:getPosition()
        love.graphics.circle("line", bx, by, BLOCK_SIZE / 2 + 5)
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
        love.graphics.print(text, windowWidth/2 - textWidth/2, windowHeight/2 - textHeight/2)
    end
end

function love.mousepressed(x, y, button)
    if gameWon then return end
    if button == 1 then  -- Left click
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
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and draggedBlock then
        -- Check if drop position overlaps player
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
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        performExplosion()
    end
end
