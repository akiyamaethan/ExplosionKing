-- Luacheck configuration for Explosion King
-- LÖVE 2D project using LuaJIT (Lua 5.1 compatible)

std = "lua51+love"

-- Global variables from LÖVE
globals = {
    "love",
}

-- Read-only globals (can be accessed but not modified)
read_globals = {
    "jit",  -- LuaJIT
}

-- Maximum line length
max_line_length = 120

-- Ignore unused loop variables starting with _
ignore = {
    "21/_.*",  -- unused variable starting with _
}

-- Files/directories to exclude
exclude_files = {
    "lib/**",      -- third-party libraries
    "vendor/**",   -- vendor code
    ".luarocks/**",
}
