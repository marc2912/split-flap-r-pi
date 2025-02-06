#!/bin/bash

set -e
set -o pipefail
set -u

# Reset color
NC='\033[0m'  
if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
    BLUE_CUSTOM='\033[38;2;47;98;155m'  
elif [[ "$TERM" =~ "256color" ]]; then
    BLUE_CUSTOM='\033[38;5;61m'  
else
    BLUE_CUSTOM=''  
fi

REPO_DIR="$HOME/split-flap-r-pi"
FORCE_UPDATE=false

# Check if the -f flag is passed
if [[ "${1:-}" == "-f" ]]; then
    FORCE_UPDATE=true
    echo -e "${BLUE_CUSTOM}⚠️ Update triggere in force update mode. Rebuilding everything.${NC}"
fi

echo -e "${BLUE_CUSTOM}🔄 Checking for SplitFlap updates...${NC}"

# Navigate to repo directory
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${BLUE_CUSTOM}❌ Error: Repository directory not found at $REPO_DIR.${NC}"
    exit 1
fi

cd "$REPO_DIR"

# Fetch latest changes without applying them
echo -e "${BLUE_CUSTOM}⬇️ Fetching latest changes...${NC}"
git fetch origin master

# Get local and remote commit hashes
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/master)

# Compare versions and check for forced update
if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" && "$FORCE_UPDATE" == "false" ]]; then
    echo -e "${BLUE_CUSTOM}Already up to date. No changes detected.${NC}"
    exit 0
fi

echo -e "${BLUE_CUSTOM}🔄 Updating repository...${NC}"
git reset --hard origin/master

# **If update.sh changed, relaunch automatically with the new version and exit**
if git diff --name-only HEAD@{1} HEAD | grep -q "update.sh"; then
    echo -e "${BLUE_CUSTOM}update.sh has changed. Relaunching script.${NC}"
    chmod +x update.sh
    exec ./update.sh -f  # Relaunch with force flag
    exit 0  # Ensures the old script stops execution
fi

# Check if dependencies changed
if git diff --name-only HEAD@{1} HEAD | grep -q "package-lock.json\|package.json"; then
    echo -e "${BLUE_CUSTOM}Dependencies changed, reinstalling...${NC}"
    npm ci
fi

# Rebuild the project only if necessary or forced
if [[ "$FORCE_UPDATE" == "true" ]] || git diff --name-only HEAD@{1} HEAD | grep -q "src/\|dist/"; then
    echo -e "${BLUE_CUSTOM}Rebuilding project...${NC}"
    npm run build
fi

# Restart the service if code changed or forced
if [[ "$FORCE_UPDATE" == "true" ]] || git diff --name-only HEAD@{1} HEAD | grep -q "dist/"; then
    echo -e "${BLUE_CUSTOM}Restarting SplitFlap service...${NC}"
    systemctl --user restart splitflap.service
fi

echo -e "${BLUE_CUSTOM}✅ Update complete!${NC}"