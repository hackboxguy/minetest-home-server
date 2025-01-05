# A Self-Sufficient/Self-Hosted Minetest Home Server

This repository contains the necessary files to generate a Docker container for **Minetest server** that includes popular games, mods, and textures. The container builds the latest versions of Minetest and its corresponding mods, games, and textures from sources. It is configured to serve:

- **Mineclonia** on port `30000`
- **Voxelibre** on port `30001`

## How to Download, Compile, and Deploy?

Follow these steps to set up the Minetest server:

1. Update the system package list:
   ```bash
   sudo apt-get update
   ```

2. Install required dependencies:
   ```bash
   sudo apt-get install git docker.io docker-compose
   ```

3. Add your user to the Docker group (requires re-login to take effect):
   ```bash
   sudo usermod -aG docker $USER
   ```

4. Clone this repository:
   ```bash
   git clone https://github.com/hackboxguy/minetest-home-server.git
   ```

5. Navigate to the project directory:
   ```bash
   cd minetest-home-server
   ```

6. Build the Docker container:
   ```bash
   docker-compose build
   ```

7. Start the server:
   ```bash
   docker-compose up -d
   ```

8. To Stop the server:
   ```bash
   docker-compose down
   ```


## Connecting to the Server

Multiple players can connect to the server at:
- `serverip:30000` for **Mineclonia**
- `serverip:30001` for **Voxelibre**

Replace `serverip` with the actual IP address or domain name of your server.

## Recommended for Families

Its an all-in-one setup ideal for families with kids who prefer to keep all players within the home network boundary. 

### Secure Your Server

Once your Minetest server is deployed and all users are registered via their Minetest clients, **it is recommended to disable further user registration** by adding **`disallow_empty_password = true`** in **`config/mineclonia.conf`** and **`config/voxelibre.conf`** files(after changing these conf files, stop and restart the server as shown in step 8 and 7 above)

### Important Note

- **`config/mineclonia.conf`** and **`config/voxelibre.conf`** files includes a pre-configured **`admin`** user with all privileges.
- After starting the Docker container, **register** first user as **`admin`** using the Minetest client and set a new password.

Enjoy your Minetest gaming experience!

