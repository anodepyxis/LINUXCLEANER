# LINUXCLEANER
Scripts for automating clean up of your operating system (OS's based on any of top 3: Debian, Fedora, Arch)
This script is written in shell language


##  IMPORTANT: 
- Script requires root or sudo access to run
- Use this script at your onw risk and test it first in a virtual environment 


**Features:**
- **Package Maintenance**
  - Fedora: cleans cache, removes unnecessary packages, orphaned files and packages, upgrades system
  - Debian: updates, upgrades, autocleans, removes old packages, cleans cache
  - Arch: updates system, removes orphaned packages, cleans cache

- **System Integrity**
  - Checks package integrity
  - Reloads and verifies systemd services
    
- **Cache and Database Rebuild:**
  - Font cache
  - MIME database
  - Desktop Application database
 
- **Log and notifciations**
   - Creates timestamped log with auto removal of older logs (older than 7 days)
  
- Environment Awareness: Understands your operating systema and your DE (desktop environment)



**Requirements:**
- Root privilges
- 'notify-send' for noficiations (OPTIONAL)
- 'debsums' for debain package verification (OPTIONAL)



## Installation: 

1. Clone this repository or download the code files
2. make the scripts executable and then open your terminal and go to the location where the file is saved and run "sudo ./(the name of the file)"



**How to execute**
- Debain, Fedora or Arch (common comamnd): "sudo chmod +x (then enter the name of the file)"
