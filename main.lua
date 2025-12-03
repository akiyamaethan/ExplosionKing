-- Explosion King - Simple Physics Scene

local world
local player
local ground
local floatingCircles = {}

-- Constants
local PLAYER_RADIUS = 30
local FLOATING_RADIUS = 12
local FLOATING_COUNT = 20
local GROUND_HEIGHT = 50

function love.load()
    -- Create physics world with gravity
    world = love.physics.newWorld(0, 500, true)

    -- Get window dimensions
    local windowWidth, windowHeight = love.graphics.getDimensions()

    -- Create ground (static body)
    ground = {}
    ground.body = love.physics.newBody(world, windowWidth / 2, windowHeight - GROUND_HEIGHT / 2, "static")
    ground.shape = love.physics.newRectangleShape(windowWidth, GROUND_HEIGHT)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)
    ground.fixture:setUserData("ground")

    -- Create player (dynamic body with gravity)
    player = {}
    player.body = love.physics.newBody(world, windowWidth / 2, windowHeight - GROUND_HEIGHT - PLAYER_RADIUS, "dynamic")
    player.shape = love.physics.newCircleShape(PLAYER_RADIUS)
    player.fixture = love.physics.newFixture(player.body, player.shape, 1)
    player.fixture:setRestitution(0.3)
    player.fixture:setUserData("player")

    -- Create floating circles (static bodies - no gravity, but collidable)
    math.randomseed(os.time())

    -- Define the "air" zone (above ground, with some padding)
    local airTop = 50
    local airBottom = windowHeight - GROUND_HEIGHT - PLAYER_RADIUS * 3
    local airLeft = FLOATING_RADIUS + 20
    local airRight = windowWidth - FLOATING_RADIUS - 20

    for i = 1, FLOATING_COUNT do
        local circle = {}

        -- Random position in the air zone
        local x = math.random(airLeft, airRight)
        local y = math.random(airTop, airBottom)

        -- Static body so it doesn't fall, but still collides
        circle.body = love.physics.newBody(world, x, y, "static")
        circle.shape = love.physics.newCircleShape(FLOATING_RADIUS)
        circle.fixture = love.physics.newFixture(circle.body, circle.shape)
        circle.fixture:setUserData("floating")

        table.insert(floatingCircles, circle)
    end
end

function love.update(dt)
    world:update(dt)

    -- Simple horizontal movement for testing
    local speed = 300
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        player.body:applyForce(-speed * 10, 0)
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        player.body:applyForce(speed * 10, 0)
    end

    -- Jump
    if love.keyboard.isDown("space") or love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        local vx, vy = player.body:getLinearVelocity()
        if math.abs(vy) < 1 then  -- Only jump if on ground (not moving vertically)
            player.body:applyLinearImpulse(0, -300)
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
        local x, y = circle.body:getPosition()
        love.graphics.circle("fill", x, y, FLOATING_RADIUS)
    end

    -- Draw player (green)
    love.graphics.setColor(0.2, 0.8, 0.2)
    local px, py = player.body:getPosition()
    love.graphics.circle("fill", px, py, PLAYER_RADIUS)

    -- Draw instructions
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("A/D or Arrow Keys to move, Space/W/Up to jump", 10, 10)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
