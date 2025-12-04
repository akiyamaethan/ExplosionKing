# Project Overview

This project is a 2D physics-based puzzle game named "Explosion King". It is built using the LÖVE (Love2D) framework and written in Lua. The core gameplay mechanic involves propelling a player character to a target by triggering explosions that push off of nearby surfaces. Players can also move and place blocks to create strategic launch platforms.

The game features multiple stages, an inventory system for carrying blocks between stages, a save/load system, and localization for English, Chinese, and Arabic. It also includes a theme system with light, dark, and time-based visual styles.

## Key Technologies

*   **Engine:** [LÖVE (Love2D)](https://love2d.org/) 11.4
*   **Language:** Lua 5.1
*   **Physics Library:** [Windfield](https://github.com/SSYGEN/windfield), a wrapper for LÖVE's Box2D-based physics engine.
*   **Rendering:** The project uses LÖVE's 2D graphics capabilities. The `README.md` also mentions the use of `3DreamEngine` for 3D-style rendering, although its usage is not directly visible in the reviewed code.

# Building and Running

## Dependencies

To run this project, you need to have LÖVE installed on your system. You can download it from the [official website](https://love2d.org/).

## Running the Game

To run the game, execute the following command in the project's root directory:

```bash
love .
```

This will launch the game in a new window.

## Development Conventions

### Linting

The project uses `luacheck` for linting Lua code. The configuration is defined in the `.luacheckrc` file, which specifies the Lua standard, global variables, and a maximum line length of 120 characters.

Linting is enforced automatically before each commit using `pre-commit`. The pre-commit hooks are configured in `.pre-commit-config.yaml` and include:

*   `luacheck` for Lua files.
*   Trailing whitespace removal.
*   End-of-file fixer.
*   Syntax checks for YAML and JSON files.
*   A check for large files.

To set up the pre-commit hooks, you need to have Python and `pip` installed. Then, run the following commands:

```bash
pip install pre-commit
pre-commit install
```

### Testing

The `README.md` mentions a "Testing Lead" and discusses playtesting, but there are no automated testing frameworks or test files apparent in the codebase.

### Deployment

The project is configured for automatic deployment to GitHub Pages. The `.github/workflows/deploy-pages.yml` file defines a GitHub Actions workflow that builds the game and deploys it whenever code is pushed to the `main` branch.
