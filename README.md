# Devlog Entry - 11/16/25
## EXPLOSION KING
Ethan Akiyama, Manvir Sohi, Humza Saulat, Joseph Coulson

## Introducing the team
Ethan as the Tools Lead: This person will research alternative tools, identify good ones, and help every other team member set them up on their own machine in the best configuration for your project. This person might also establish your team’s coding style guidelines and help peers setup auto-formatting systems. This person should provide support for systems like source control and automated deployment (if appropriate to your team’s approach).

Joseph as the Engine Lead: This person will research alternative engines, get buy-in from teammates on the choice, and teach peers how to use it if it is new to them. This might involve making small code examples outside of the main game project to teach others. The Engine Lead should also establish standards for which kinds of code should be organized into which folders of the project. They should try to propose software designs that insulate the rest of the team from many details of the underlying engine.

Manvir as the Design Lead: This person will be responsible for setting the creative direction of the project, and establishing the look and feel of the game. They might make small art or code samples for others to help them contribute and maintain game content. Where the project might involve a domain-specific language, the Design Lead (who is still an engineer in this class) will lead the discussion as to what primitive elements the language needs to provide.

Humza as the Testing Lead:  This person will be responsible for both any automated testing that happens within the codebase as well as organizing and reporting on human playtests beyond the team.
If your team has fewer than four people, some people will need to be the lead for multiple disciplines, but no person should be the lead for more than two disciplines.


## Tools and materials
Engine: We plan to use LÖVE (Love2D) as our engine. LÖVE is a lightweight 2D framework that does not include high-level 3D rendering or physics out of the box, which keeps it fully within the F1 requirements. It provides just enough structure to handle window creation, rendering, and input, while still requiring us to implement or integrate our own physics and 3D-style effects as needed. Our team chose LÖVE because it is simple, flexible, and beginner-friendly, and because it gives us full control over the systems we want to build for our physics-driven gameplay.

Language: Our project will be written primarily in Lua, the scripting language used by LÖVE. Lua is lightweight, easy to learn, and fast enough for real-time game logic, making it a     natural fit for our project. We also expect to use JSON for any structured data we may need (such as level descriptions or object properties). Lua’s simple syntax and the engine’s tight integration with it will allow us to develop gameplay systems—such as explosions, forces, and object interactions—efficiently.

Tools: To support 3D-style rendering inside a 2D engine, we will be using 3DreamEngine, a rendering framework compatible with LÖVE. This will allow us to incorporate depth, lighting, and more visually interesting effects into our physics sandbox while still building everything on top of a low-level platform. For general development, we will use standard tools such as a Lua-friendly code editor (e.g., VS Code) and any simple asset-creation tools we may need. We chose these tools because they complement our team’s existing skill sets and because they strike a good balance between flexibility and learning opportunities.

Generative AI: The team will be using gemini cli (a free agentic terminal level AI) as a helper when we are stuck and to make sure that we are adhering to our code stylesheet.

## Outlook
What is your team hoping to accomplish that other teams might not attempt? We hope to create a game where the player is physics puzzle.

What do you anticipate being the hardest or riskiest part of the project? We anticipate the physics mechanism for the player will be the most tricky thing to get right.

What are you hoping to learn by approaching the project with the tools and materials you selected above? We are hoping to learn how to use a style sheet to maintain consistent code amongst collaborators. We are also hoping to gain some experience adapting to changing requirements like in the real world.

# Devlog Entry - 12/2/25

## How we satisfied the software requirements
1 - Platform without built-in 3D rendering or physics: We built this Explosion King prototype using LÖVE (Love2D), a lightweight 2D game framework written in Lua. LÖVE does not provide any native 3D rendering capabilities—it's designed purely for 2D graphics using OpenGL primitives like circles, rectangles, and sprites.

2 - Third-party 3D rendering library: Our project uses 3DreamEngine, a third-party 3D rendering library designed specifically for LÖVE. This library enables us to add depth, lighting, and pseudo-3D visual effects on top of LÖVE's 2D foundation. 3DreamEngine handles the heavy lifting of perspective projection, mesh rendering, and lighting calculations—features that LÖVE simply doesn't provide out of the box. By integrating 3DreamEngine, we can create visually interesting explosion effects and environmental depth while still building our core game logic on LÖVE's straightforward 2D architecture.

3 - Third-party physics simulation library: The game relies on Windfield, a third-party physics library that provides a clean, developer-friendly wrapper around Box2D. We imported Windfield into our `libraries/windfield` directory and use it extensively throughout `main.lua` for creating the physics world, defining collision classes (Ground, Wall, Player, Block, BlockDragging), spawning colliders, and applying forces. Windfield's API made it like ridiculously easy to set up gravity, handle collision detection between the player and environment, and implement our custom explosion force calculations that query nearby objects within a radius.

4 - Physics-based puzzle: The Explosion King prototype presents players with a straightforward physics puzzle: reach the bullseye target in the top-right corner of the screen. The catch is that players cannot directly move their avatar—instead, they must use an explosion mechanic (triggered by spacebar) that calculates repulsion forces based on proximity to nearby surfaces. The explosion pushes the player away from the ground, walls, and any building blocks within the blast radius. Players must think strategically about positioning and trajectory, using the physics system to propel themselves toward the goal.

5 - Player control affecting success or failure: Players exert control over the simulation in two key ways. First, they can drag and reposition three black building blocks anywhere in the scene to create platforms and launch surfaces. Second, they trigger explosions with precise timing to propel their avatar. The placement of blocks directly affects the direction and magnitude of explosion forces—positioning a block below the player provides upward thrust, while blocks to the side enable horizontal movement. Poor block placement or mistimed explosions will absolutely send the player careening in the wrong direction, making success entirely dependent on the player's strategic decisions.

6 - Success/failure detection with graphical feedback: The game detects victory by checking if the player's circular avatar overlaps with the target's radius during each update cycle. When the player reaches the target, a semi-transparent black overlay covers the entire window, and "VICTORY" text appears centered on screen. The physics simulation also stops updating, giving players clear visual confirmation that they've completed the puzzle.

7 - Before-commit automation (Linting): We implemented pre-commit hooks using the `pre-commit` framework, configured in `.pre-commit-config.yaml`. Our setup runs Luacheck on all `.lua` files before every commit, catching syntax errors, undefined globals, and style violations automatically. We also configured additional hooks for trailing whitespace removal, end-of-file fixes, YAML/JSON validation, and large file detection. The `.luacheckrc` file customizes Luacheck for LÖVE development by setting the Lua 5.1 standard with LÖVE globals and establishing a 120-character line limit. This automation ensures consistent code quality across all team contributions.

8 - Post-push automation (Deployment): We set up a GitHub Actions workflow (`.github/workflows/deploy-pages.yml`) that automatically builds and deploys the game to GitHub Pages whenever code is pushed to the main branch. The workflow packages all game files into a `.love` archive, uses `love.js` to compile the game to WebAssembly, generates a custom HTML page with styled canvas embedding, and deploys the result to GitHub Pages. This means every push to main automatically updates our publicly playable web version.

## Reflection
Surprisingly, we have been able to use the same tools we originally decided on as of now. We had to add one more (windfield) to account for 3rd party physics, but other than that our stack has remained the same. We kind of fibbed our team roles and we have all been pretty much covering all the roles so maybe we can work on tightening that up for the next milestone. Game design-wise, our plans have changed drastically. We originally wanted to go with preset levels that put the player somewhere with a goal to reach elsewhere and just let them press space at the right time until they reached it. This was reminiscent of Geometry Dash. As you will see, for this milestone, we have pivoted to a sandbox sort of design. We now present the player with a pretty much emtpy level, but provide them shapes to place around the level and form their own solution to the problem. We think this will be much more interesting moving forward. 



## Next steps:
Next up, We need to add another scene that the player can bring building blocks into using their inventory. This scene should be a copy of the first scene but with the target in the top left.