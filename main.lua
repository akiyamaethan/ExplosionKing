-- Explosion King - Explosion-Based Movement

local wf = require 'libraries.windfield.windfield'

local world
local player
local ground
local walls = {}  -- Screen boundary walls
local floatingCircles = {}

-- Constants
local PLAYER_RADIUS = 30
local FLOATING_RADIUS = 12
local FLOATING_COUNT = 20
local GROUND_HEIGHT = 50

-- Explosion constants
local EXPLOSION_RADIUS = PLAYER_RADIUS * 3  -- 3x player radius
local EXPLOSION_FORCE = 1600  -- Base force, tuned to launch ~1/3 screen height from ground

-- Custom circle query that handles both circle and polygon shapes
-- (Windfield's queryCircleArea has a bug with circle shapes)
function queryCircleArea(world, cx, cy, radius)
    local colliders = world:queryCircleArea(cx, cy, radius, {'All'})
    return colliders
end

-- Simple distance-based query as fallback
function getCollidersInRadius(cx, cy, radius, colliderList, groundCollider)
    local results = {}

    -- Check ground (rectangle) - use closest point on rectangle
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local groundTop = windowHeight - GROUND_HEIGHT

    -- If player is within radius of ground surface
    if cy + radius >= groundTop then
        table.insert(results, {collider = groundCollider, x = cx, y = groundTop})
    end

    -- Check floating circles
    for _, circle in ipairs(colliderList) do
        local ox, oy = circle:getPosition()
        local dist = math.sqrt((cx - ox)^2 + (cy - oy)^2)

        -- Account for the floating circle's radius
        if dist - FLOATING_RADIUS <= radius then
            table.insert(results, {collider = circle, x = ox, y = oy})
        end
    end

    return results
end

function love.load()
    -- Create physics world with gravity using Windfield
    world = wf.newWorld(0, 500, true)

    -- Define collision classes for different object types
    world:addCollisionClass('Ground')
    world:addCollisionClass('Wall')
    world:addCollisionClass('Player')
    world:addCollisionClass('Floating')

    -- Get window dimensions
    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Create ground (static body) - Windfield makes this insanely simple
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

    -- Create floating circles (static bodies - no gravity, but collidable)
    math.randomseed(os.time())

    -- Define the "air" zone (above ground, with some padding)
    local airTop = 50
    local airBottom = windowHeight - GROUND_HEIGHT - PLAYER_RADIUS * 3
    local airLeft = FLOATING_RADIUS + 20
    local airRight = windowWidth - FLOATING_RADIUS - 20

    for i = 1, FLOATING_COUNT do
        -- Random position in the air zone
        local x = math.random(airLeft, airRight)
        local y = math.random(airTop, airBottom)

        -- Static body so it doesn't fall, but still collides
        local circle = world:newCircleCollider(x, y, FLOATING_RADIUS)
        circle:setType('static')
        circle:setCollisionClass('Floating')

        table.insert(floatingCircles, circle)
    end
end

function love.update(dt)
    world:update(dt)
end

-- Perform explosion - query nearby objects and calculate repulsion force
function performExplosion()
    local px, py = player:getPosition()

    -- Use our custom query that handles circle shapes properly
    local nearbyObjects = getCollidersInRadius(px, py, EXPLOSION_RADIUS, floatingCircles, ground)

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
            -- Objects at edge of explosion radius contribute less
            local strength = 1 - (distance / EXPLOSION_RADIUS)
            strength = math.max(0, strength)  -- Clamp to positive

            forceX = forceX + dx * strength
            forceY = forceY + dy * strength
            objectsInRange = objectsInRange + 1
        else
            -- Object is exactly at player position (like ground directly below)
            -- Default to pushing up
            forceY = forceY - 1
            objectsInRange = objectsInRange + 1
        end
    end

    -- Only apply force if there are objects to push off of
    if objectsInRange > 0 then
        -- Normalize the combined force direction
        local magnitude = math.sqrt(forceX * forceX + forceY * forceY)

        if magnitude > 0 then
            forceX = forceX / magnitude
            forceY = forceY / magnitude

            -- Apply impulse in the calculated direction
            -- Scale by number of objects for a more dramatic effect when surrounded
            local finalForce = EXPLOSION_FORCE * math.min(objectsInRange, 3)
            player:applyLinearImpulse(forceX * finalForce, forceY * finalForce)
        end
    end
end

function love.draw()
    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Draw sky background
    love.graphics.setBackgroundColor(0.5, 0.7, 0.9)

    -- Draw ground (brown)
    love.graphics.setColor(0.4, 0.3, 0.2)
    love.graphics.rectangle("fill", 0, windowHeight - GROUND_HEIGHT, windowWidth, GROUND_HEIGHT)

    -- Draw floating circles (black)
    love.graphics.setColor(0, 0, 0)
    for _, circle in ipairs(floatingCircles) do
        local x, y = circle:getPosition()
        love.graphics.circle("fill", x, y, FLOATING_RADIUS)
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
    love.graphics.print("Press SPACE to explode and propel off nearby objects!", 10, 10)

    -- Optional: Draw debug physics shapes (uncomment to see collision shapes)
    -- world:draw()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        performExplosion()
    end
end
