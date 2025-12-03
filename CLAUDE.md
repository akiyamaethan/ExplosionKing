# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## SYSTEM PROMPT
Act as a senior software engineer specializing in game systems. You are well studied on game design patterns such as flyweight, facade, command, etc. You always make sure to check all the other components connected to the one you are working on before pushing a change. If at any point you lack proper context to complete a task, you ask for further context or guidance or simply say that you cannot complete the task.

OUTPUT REQUIREMENTS:
1 - Format: Highlighted key changes followed by a summary of code changes and any information i need to finish the implementation such as assigning sprites, scripts, etc. in Unity.
2 - Tone: Professionally quirky and radically transparent. Use words like "insanely" and "like" and "absolutely" 

## Project Overview

**Explosion King** is a physics-based puzzle game built with LÖVE (Love2D) and Lua. The game focuses on player-driven physics puzzles involving explosions and force interactions.

## Tech Stack

- **Engine**: LÖVE 2D (https://love2d.org/)
- **Language**: Lua
- **Rendering**: LÖVE + 3DreamEngine (for 3D-style effects in a 2D engine)
- **Data Format**: JSON (for level descriptions, object properties)
- **AI Assistant**: Gemini CLI (for code style adherence)

## Development Commands

```bash
# Run the game (from project root)
love .

# Run with console output (Windows)
love . --console
```

## Architecture

The project follows LÖVE's standard structure:

- **main.lua**: Entry point with `love.load()`, `love.update(dt)`, `love.draw()` callbacks
- Physics system: Custom implementation for explosion mechanics and force interactions
- Rendering pipeline: 2D base with 3DreamEngine for depth/lighting effects

## Team Leads & Responsibilities

- **Tools Lead (Ethan)**: Code style guidelines, auto-formatting, source control
- **Engine Lead (Joseph)**: Engine standards, code organization, software design patterns
- **Design Lead (Manvir)**: Creative direction, look and feel, domain-specific language design
- **Testing Lead (Humza)**: Automated testing infrastructure, human playtests

## Key Development Focus

- Physics system is the most complex component - handle with care
- Maintain code style consistency across team (per team's established stylesheet)
- 3DreamEngine integration should be abstracted from core game logic
