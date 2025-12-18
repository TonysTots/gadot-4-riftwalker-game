Project Title: Riftwalker - Game Client

IMPORTANT: PREREQUISITE
Before running the game client, you MUST verify that the Riftwalker Website/Server is running locally.
Please refer to the Website repository's readme file and complete those steps first. The game requires the server to be running on localhost to handle authentication, cloud saves, and leaderboards.

Operation Platform
- Developed and tested on Windows 10 / 11.

Implemented Programming Language
- GDScript 2.0 (Godot 4)

Required Libraries and Dependencies
- Godot Engine 4.x (Standard Edition)
- No external plugins are currently required; all assets and scripts are included in the repository.

Steps to Run the System
1. Ensure the Riftwalker Website (Server) is running locally (as per the Website Readme).
2. Download the Godot Engine (Version 4.0 or higher) from https://godotengine.org/.
3. Launch Godot and click "Import".
4. Navigate to the local folder where you cloned this repository.
5. Select the 'project.godot' file to import the project.
6. **IMPORTANT CONFIGURATION:**
    - Open the script `RiftWalker/autoloads/auth_manager.gd`.
    - Locate the specific line defining the base URL (e.g., `var base_url = "http://localhost:5296/api"`).
    - Modify this URL to match the port your local server is actually running on (check your server console output).
7. Once configured, press F5 (or the "Play" button in the top right corner) to run the game.

Other Notes
- The game is configured to connect to localhost by default.
- If you encounter network errors, verify the server is running and the port in `auth_manager.gd` is correct.
