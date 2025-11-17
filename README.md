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

What are you hoping to learn by approaching the project with the tools and materials you selected above? We are hoping to learn how to use a style sheet to maintain consistent code amongst collaborators. We are also hoping to gain some experience adapting to changing requirements like in the real world.. .    .