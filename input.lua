-- input.lua - Unified Input Abstraction Layer
-- Treats mouse and touch as a single "pointer" concept

local Input = {}

-- Internal state
local activePointerId = nil      -- nil for mouse, touch ID for touch
local pointerX, pointerY = 0, 0
local pointerDown = false
local pointerSource = nil        -- "mouse" or "touch"

-- Callbacks (set by main.lua)
Input.onPointerPressed = nil     -- function(x, y)
Input.onPointerReleased = nil    -- function(x, y)

-- Public API
function Input.getPosition()
    return pointerX, pointerY
end

function Input.isDown()
    return pointerDown
end

function Input.getSource()
    return pointerSource
end

-- Mouse handlers
function Input.handleMousePressed(x, y, button)
    if button ~= 1 or pointerDown then return false end
    activePointerId = nil
    pointerSource = "mouse"
    pointerX, pointerY = x, y
    pointerDown = true
    if Input.onPointerPressed then Input.onPointerPressed(x, y) end
    return true
end

function Input.handleMouseReleased(x, y, button)
    if button ~= 1 or pointerSource ~= "mouse" then return false end
    pointerX, pointerY = x, y
    pointerDown = false
    if Input.onPointerReleased then Input.onPointerReleased(x, y) end
    return true
end

-- Touch handlers
function Input.handleTouchPressed(id, x, y)
    if pointerDown then return false end  -- Already tracking a pointer
    activePointerId = id
    pointerSource = "touch"
    pointerX, pointerY = x, y
    pointerDown = true
    if Input.onPointerPressed then Input.onPointerPressed(x, y) end
    return true
end

function Input.handleTouchReleased(id, x, y)
    if id ~= activePointerId then return false end
    pointerX, pointerY = x, y
    pointerDown = false
    activePointerId = nil
    if Input.onPointerReleased then Input.onPointerReleased(x, y) end
    return true
end

function Input.handleTouchMoved(id, x, y)
    if id ~= activePointerId then return false end
    pointerX, pointerY = x, y
    return true
end

-- Update pointer position from mouse (for when no active touch)
function Input.updateFromMouse()
    if pointerSource == "mouse" or not pointerDown then
        pointerX, pointerY = love.mouse.getPosition()
    end
end

return Input
