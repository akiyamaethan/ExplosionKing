# Explosion King - Lua Style Guide

This document outlines the coding style and conventions used in the Explosion King project. Following these guidelines helps to keep the codebase consistent, readable, and maintainable.

## 1. Naming Conventions

- **`camelCase` for Variables and Functions:** Local variables, module-level variables, and function names should be written in `camelCase`.
  ```lua
  local draggedBlock = nil
  function handlePointerPressed(x, y)
      -- ...
  end
  ```

- **`PascalCase` for Modules/Classes:** Files that act as a "class" or module and return a table should be named in `PascalCase`. The variable holding the required module should also be `PascalCase`.
  ```lua
  -- in input.lua
  local Input = {}
  -- ...
  return Input

  -- in main.lua
  local Input = require 'input'
  ```

- **`UPPER_SNAKE_CASE` for Constants:** Variables that are treated as constants (i.e., their value does not change after initialization) should be in `UPPER_SNAKE_CASE`.
  ```lua
  local PLAYER_RADIUS = 30
  local FONT_SIZE = 14
  ```

## 2. Formatting

- **Indentation:** Use four spaces (tabs) for each indentation level.

- **Spacing:**
  - Use a single space around binary operators (`=`, `+`, `-`, `*`, `/`, `==`, `~=`, etc.) and after commas.
    ```lua
    local x = y + 5
    local t = {1, 2, 3}
    love.graphics.print("Hello", 10, 20)
    ```
  - Do not put a space between a function name and the opening parenthesis of its arguments.
    ```lua
    function myFunction(arg1)
        -- ...
    end
    ```

- **Blank Lines:**
  - Use a **single blank line** to separate logical blocks of code within a function.
  - Use **one or two blank lines** to separate top-level functions and variable declarations.

- **Line Length:** Aim to keep lines under 120 characters where possible.

## 3. Comments

- **Style:** Use `--` for all comments. Avoid block comments (`--[[ ... ]]`) for documentation. Use lower case.
- **Purpose:** Write comments to explain the *why*, not the *what*. Assume the reader understands Lua, but may not understand the purpose of your code.
- **Tone:** Keep it light, we don't need all that jargon all the time. Save it for when it counts.
  ```lua
  -- good: explains the purpose
  -- keep block on screen
  newX = math.max(halfSize, math.min(windowWidth - halfSize, newX))

  -- bad: just repeats the code
  -- set newX to the maximum of halfSize and the minimum of ...
  newX = math.max(halfSize, math.min(windowWidth - halfSize, newX))
  ```
- **Section Headers:** Use comments to create clear sections for different parts of the file. Capitalize the headers.
  ```lua
  -------------------------
  -- Explosion Constants --
  -------------------------
  local EXPLOSION_RADIUS = PLAYER_RADIUS * 3
  ```

## 4. Code Structure

- **File Organization:**
  - `main.lua`: Contains the main game loop and LÖVE callbacks.
  - Other `.lua` files should be self-contained modules that are `require`'d by `main.lua` or other modules.

- **Module Structure:** Modules should declare a local table, add their public functions and variables to it, and return it at the end of the file.
  ```lua
  -- my_module.lua
  local MyModule = {}

  function MyModule.doSomething()
      -- ...
  end

  return MyModule
  ```

- **`main.lua` Structure:** Organize `main.lua` in the following order:
  1. `require` statements for external libraries and modules.
  2. Module-level local variables (game state, constants, etc.).
  3. Helper functions (local functions that are not LÖVE callbacks).
  4. LÖVE callback functions (`love.load`, `love.update`, `love.draw`, etc.).

## 5. Language Conventions

- **Scope:** Always use the `local` keyword for variables and functions unless there is a specific reason for them to be global. The only globals should be the LÖVE callbacks (`love.load`, etc.).
- **Tables:**
  - Use trailing commas in multi-line table definitions. This makes it easier to add new lines and results in cleaner diffs.
    ```lua
    local myTable = {
        a = 1,
        b = 2,
        c = 3, -- trailing comma
    }
    ```
  - When a table is a simple list, use `ipairs`. When it is a dictionary, use `pairs`.
