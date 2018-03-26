# RobotMiningSuite

Suite of Lua programs used on a robot and command computer that allows the robot to identify potential loot, determine the most efficent path to mine it, and allow the computer to take loot locations and represent them on a hologram array. Built for the OpenComputers mod of Minecraft.

## Game Requirements

This suite of software was developed to only depend on using OpenComputers and vanilla Minecraft. Other mods are not required in order to use this suite, however IC2 was present during it's development and the mining drill was used as the primary mining tool for the robot. 

This code was developed on:

- Minecraft 1.10.2
- OpenComputers 1.6.0

This code was developed some time ago and the server it was developed on has long since been shut down. I cannot verify that these version numbers are correct.

## In-Game Target Machine Setup

This software suite requires the following in-game components: 

- One central computer for issuing commands, expediting route calculation, and hosting the holograms used to display the route.
- One robot equipped with a geolyzer, wireless network and mining capabilities.

### Robot Components

#### Required:

- Geolyzer
- Inventory Controller Upgrade
- Navigation Upgrade
- Wireless Network Card
- Tier 1 Monitor 
- Keyboard

#### Optional/Variable:

- Chuckloader Upgrade (not really necessary, but highly recommended)
- Inventory Upgrade (possibly multiple)
- Battery Upgrade (possibly multiple)
- Other components optional but recommend maximum specs

### Home Computer Components

- Tier 3 Graphics Card
- Two Tier 2 Hologram units (one placed 13 blocks above the other - to verify height)
- Wireless Network Card
- Other standard computer components, minding minimum RAM, hard drive space, and processor requirements for above.

## Installation

The project is broken out into three sections, by directory. Code in the Robot directory is to be installed on the Robot. Code in the Computer directory is to be installed on the main home computer. Code in the Common directory must be installed on both.

1. Construct the machines specified in the In-Game Target Machine Setup section.
2. Place the robot at a desired location. This should be close enough for it to drop loot at your base, but the farther it is from where you want to scan, the more battery is consumed trying to get to destinations rather than scanning.
3. Set up the supporting robot equipment, including the charger and the loot drop. When placing, know that the robot will move in the X direction first, so the charger and loot chest should not be on that axis. It is recommended that the loot chest be connected to other chests by hopper or by a Buildcraft system (or equivalent item handling mechanism) since the robot will pick up large quantities of material.
4. Copy the lua files located under the Robot and Common directories onto the robot. All files should be in the same directory, but need not be in the root directory.
5. Modify the movemine.lua program to provide the correct XHOME, YHOME, and ZHOME coordinates for the robot. The values can be found using the "component.navigation.getPosition()" command on the robot.
6. Modify the ordermine.lua program to set the correct loot drop direction (which direction should the robot interact with to drop loot into a chest or inventory system).
7. (Optional) Modify any other constants in the geoscan.lua and ordermine.lua programs to match the setup of the system or fit user wishes (such as minimum power before returning or the count of inventory upgrades).
8. Set up the home computer. This must be within wireless range of the robot (see the wireless card to figure that out). 
9. Copy the lua files located under the Computer and Common directories onto the home computer. All files should be in the same directory, but need not be in the root directory.
10. Modify the findmineorder.lua program to provide the correct XHOME, YHOME, and ZHOME coordinates of the robot. These are the same values placed in movemine.lua above.
11. (Optional) Add the hologram units. They should be placed in a large room to allow viewing all viewable blocks of both holograms. Due to limitations on the hologram, there will be a cable in the middle of the room to provide power and data to the higher of the two holograms.
12. (If installing holograms) Modify the uploadscantoholo.lua program to set the holo and holo2 variables to the appropriate device addresses. Use the "components" command in OpenOS to list all components and their addresses.

## Operation

1. Run the geoscan.lua program on the robot. The robot will wait for commands from the main computer.
2. Run the geoscancontrol.lua program on the main computer. 
3. Provide the relative location for the robot to perform the scan. Once these relative coordinates are provided, the robot will automatically start the scan.
4. Wait for the robot to complete the scan. The main computer will state "Program Complete!" when it is done. 
5. (Optional) View the layout of the mining area using findmineorder.lua on the main computer. Blue is air. Yellow is potential loot. Red is water or lava.
6. Find the number of value/loot files that were aquired during the scan. The loot listing is split among multiple files to keep RAM requirements minimal. All files will be under the "scanresults" directory which will be located next to the geoscancontrol.lua program.
7. Run the findmineorder.lua program on the main computer.
8. Provide the number of loot/value files to the program. It will process the loot results and determine the route the robot should take to mine everything. The program will list the number of command files to run. This will be used later.
9. Run the ordermine.lua program on the robot. The robot will wait for commands from the main computer.
10. Run the orderminecontrol.lua program on the main computer.
11. Provide the number of command files listed by the results of findmineorder.lua.

## Comments

I recognize this software suite has room for improvement. It was brought to an operational point, but has several points of refinement and automation that can be added. I'll get to it someday.