#!/bin/bash

# ===============================
# Ritual Node One-Click Run Script
# ===============================

# Menu options
options=("Setup Node" "Start Node" "Stop Node" "Check Logs" "Deploy Hello World Contract" "Call Hello World Contract" "Exit")
selected=0

# Handle Ctrl+C
trap "echo -e '\nExiting...'; exit 0" SIGINT

# === Functions ===

setup_node() {
  echo ">>> Setting up Ritual Node environment..."

  # Check and install Docker
  if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
    echo "Docker installed successfully."
  else
    echo "Docker is already installed."
  fi

  # Enable and start Docker service
  if systemctl list-unit-files | grep -q docker.service; then
    echo "Enabling and starting Docker service..."
    sudo systemctl enable --now docker
    echo "Docker service is active."
  fi

  # Check and install Docker Compose
  if ! docker compose version &> /dev/null; then
    echo "Docker Compose not found. Installing Docker Compose..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) \
      -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
    echo "Docker Compose installed successfully."
  else
    echo "Docker Compose is already installed."
  fi

  # Decide target directory based on user
  if [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/root/infernet-container-starter"
  else
    TARGET_DIR="$HOME/infernet-container-starter"
  fi

  # Clone Ritual Infernet starter if not exists
  if [ ! -d "$TARGET_DIR" ]; then
    echo "Cloning Ritual Infernet Container Starter into $TARGET_DIR..."
    git clone https://github.com/ritual-net/infernet-container-starter "$TARGET_DIR"
    echo "Repository cloned to $TARGET_DIR."
  else
    echo "Directory $TARGET_DIR already exists. Skipping clone."
  fi

  # === Deploy Hello World container in background using screen ===
  echo "Deploying hello-world container in background..."
  docker pull ritualnetwork/hello-world-infernet:latest 
  screen -dmS ritual-node bash -c "cd $TARGET_DIR && project=hello-world make deploy-container"
  echo "✅ Hello World container deployment started in screen session 'ritual-node'"

  # Ensure jq is installed for JSON editing
  if ! command -v jq &> /dev/null; then
    echo "jq not found. Installing jq..."
    sudo apt-get update -y && sudo apt-get install -y jq
  fi

  # === Prompt for RPC URL ===
  default_rpc="https://mainnet.base.org"
  while true; do
    read -p "Enter RPC URL [default: $default_rpc]: " user_rpc
    rpc_url=${user_rpc:-$default_rpc}
    if [[ "$rpc_url" =~ ^https?://.+ ]]; then
      break
    else
      echo "❌ Invalid RPC URL. Must start with http:// or https://"
    fi
  done

  # === Prompt for Private Key ===
  echo ""
  while true; do
    read -p "Private Key: Enter your private key (throwaway wallet). Add '0x' if missing: " user_priv

    if [ -z "$user_priv" ]; then
      private_key="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
      echo "⚠️  No input detected, using demo private key (NOT for production)."
      break
    fi

    if [[ "$user_priv" =~ ^0x ]]; then
      private_key="$user_priv"
    else
      private_key="0x$user_priv"
      echo "ℹ️  Added missing '0x' prefix to your private key."
    fi

    if [[ ${#private_key} -ne 66 ]]; then
      echo "❌ Invalid private key length. Expected 64 hex characters."
      continue
    fi

    if [[ ! "$private_key" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
      echo "❌ Invalid private key format. Must be 64 hex characters (0-9, a-f)."
      continue
    fi
    break
  done

  # === Prompt for SENDER Address ===
  echo ""
  while true; do
    read -p "SENDER Address: Enter your wallet address (must start with 0x): " user_sender

    if [ -z "$user_sender" ]; then
      echo "❌ Address cannot be empty."
      continue
    fi

    if [[ ! "$user_sender" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
      echo "❌ Invalid address. Must be 0x followed by 40 hex characters."
      continue
    fi

    sender_address="$user_sender"
    break
  done

  # === Prompt for Docker Hub Username & Password ===
  read -p "Enter Docker Hub Username: " docker_user
  read -s -p "Enter Docker Hub Password: " docker_pass
  echo ""

  # === Prompt for Snapshot Sync config ===
  read -p "Enter snapshot_sync sleep (default 3): " user_sleep
  snap_sleep=${user_sleep:-3}

  read -p "Enter snapshot_sync batch_size (default 50): " user_batch
  snap_batch=${user_batch:-50}

  read -p "Enter snapshot_sync sync_period (default 30): " user_period
  snap_period=${user_period:-30}

    # === Update config.json (deploy & hello-world/container) ===
  for CFG_FILE in "$TARGET_DIR/deploy/config.json" "$TARGET_DIR/projects/hello-world/container/config.json"; do
    if [ -f "$CFG_FILE" ]; then
      jq --arg url "$rpc_url" \
         --arg pkey "$private_key" \
         --arg duser "$docker_user" \
         --arg dpass "$docker_pass" \
         --argjson sleep "$snap_sleep" \
         --argjson batch "$snap_batch" \
         --argjson period "$snap_period" \
         '.chain.rpc_url = $url |
          .chain.wallet.private_key = $pkey |
          .docker.username = $duser |
          .docker.password = $dpass |
          .chain.trail_head_blocks = 3 |
          .chain.snapshot_sync.sleep = $sleep |
          .chain.snapshot_sync.batch_size = $batch |
          .chain.snapshot_sync.sync_period = $period' \
          "$CFG_FILE" > "$CFG_FILE.tmp" && mv "$CFG_FILE.tmp" "$CFG_FILE"
      echo "✅ Updated $CFG_FILE"
    else
      echo "⚠️ Config file not found: $CFG_FILE"
    fi
  done

  # Stop hello world
  echo "Shutting down hello world, please wait..."
  project=hello-world make stop-container
  # Tunggu sampai container benar-benar mati
  while docker ps --format '{{.Names}}' | grep -q "infernet"; do
    echo "⏳ Still stopping hello-world container..."
    sleep 2
  done

  echo "✅ Hello World container stopped completely."

  # === Update docker-compose.yaml image version ===
  COMPOSE_FILE="$TARGET_DIR/deploy/docker-compose.yaml"
  if [ -f "$COMPOSE_FILE" ]; then
    echo "Updating docker-compose.yaml image version..."
    sed -i 's|image: ritualnetwork/infernet-node:1.3.1|image: ritualnetwork/infernet-node:latest|g' "$COMPOSE_FILE"
    echo "✅ docker-compose.yaml updated to use image: ritualnetwork/infernet-node:latest"
  else
    echo "⚠️ docker-compose.yaml not found at $COMPOSE_FILE, skipping..."
  fi

  # === Update Makefile for contracts ===
  MAKEFILE_PATH="$TARGET_DIR/projects/hello-world/contracts/Makefile"
  if [ -f "$MAKEFILE_PATH" ]; then
    echo "Updating Makefile with user RPC, Private Key and SENDER..."
    cat > "$MAKEFILE_PATH" <<EOL
# phony targets are targets that don't actually create a file
.phony: deploy call-contract

# user provided key, rpc and sender address
PRIVATE_KEY := $private_key
RPC_URL := $rpc_url
SENDER := $sender_address

# deploying the contract
deploy:
	@PRIVATE_KEY=\$(PRIVATE_KEY) forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url \$(RPC_URL) --sender \$(SENDER) --private-key \$(PRIVATE_KEY)

# calling sayGM()
call-contract:
	@PRIVATE_KEY=\$(PRIVATE_KEY) forge script script/CallContract.s.sol:CallContract --broadcast --rpc-url \$(RPC_URL)
EOL
    echo "✅ Makefile updated successfully!"
  else
    echo "⚠️ Makefile not found at $MAKEFILE_PATH, skipping..."
  fi

  # === Prompt for Registry Address ===
  default_registry="0x3B1554f346DFe5c482Bb4BA31b880c1C18412170"
  read -p "Enter Registry Address [default: $default_registry]: " user_registry
  registry_address=${user_registry:-$default_registry}

  # === Update Deploy.s.sol ===
  DEPLOY_FILE="$TARGET_DIR/projects/hello-world/contracts/script/Deploy.s.sol"
  if [ -f "$DEPLOY_FILE" ]; then
    echo "Updating Deploy.s.sol with SENDER and Registry..."
    cat > "$DEPLOY_FILE" <<EOL
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {SaysGM} from "../src/SaysGM.sol";

contract Deploy is Script {
    function run() public {
        // Setup wallet
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); // not used
        vm.startBroadcast();

        // Log address
        address deployerAddress = $sender_address;
        console2.log("Loaded deployer: ", deployerAddress);

        address registry = $registry_address;
        // Create consumer
        SaysGM saysGm = new SaysGM(registry);
        console2.log("Deployed SaysHello: ", address(saysGm));

        // Execute
        vm.stopBroadcast();
        vm.broadcast();
    }
}
EOL
    echo "✅ Deploy.s.sol updated successfully!"
  else
    echo "⚠️ Deploy.s.sol not found at $DEPLOY_FILE, skipping..."
  fi

  # === Install Foundry ===
  echo "Installing Foundry..."
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc
  foundryup
  echo "✅ Foundry installed successfully!"

  echo ">>> Ritual Node setup complete. Current directory: $(pwd)"
  read -p "Press Enter to return to menu..."
}

start_node() {
  echo ">>> Starting Ritual node..."
  if [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/root/infernet-container-starter"
  else
    TARGET_DIR="$HOME/infernet-container-starter"
  fi

  cd "$TARGET_DIR" || { echo "Project folder not found!"; return; }
  docker pull ritualnetwork/hello-world-infernet:latest 

  docker compose -f "$TARGET_DIR/deploy/docker-compose.yaml" up --build -d
  echo "✅ Ritual node started."
  read -p "Press Enter to return to menu..."
}

stop_node() {
  echo ">>> Stopping Ritual node..."
  if [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/root/infernet-container-starter"
  else
    TARGET_DIR="$HOME/infernet-container-starter"
  fi
  cd "$TARGET_DIR" || { echo "Project folder not found!"; return; }
  docker compose -f "$TARGET_DIR/deploy/docker-compose.yaml" down
  echo "✅ Ritual node stopped."
  read -p "Press Enter to return to menu..."
}

check_logs() {
  echo ">>> Checking Ritual node logs..."
  if [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/root/infernet-container-starter"
  else
    TARGET_DIR="$HOME/infernet-container-starter"
  fi
  cd "$TARGET_DIR" || { echo "Project folder not found!"; return; }
  docker compose -f "$TARGET_DIR/deploy/docker-compose.yaml" logs -f
  read -p "Press Enter to return to menu..."
}

deploy_hello_world_contract() {
  echo ">>> Deploying Hello World Contract..."
  if [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/root/infernet-container-starter"
  else
    TARGET_DIR="$HOME/infernet-container-starter"
  fi
  cd "$TARGET_DIR/projects/hello-world/contracts" || { echo "Contracts folder not found!"; return; }
  make deploy
  read -p "Press Enter to return to menu..."
}

call_hello_world_contract() {
  echo ">>> Calling Hello World Contract..."
  if [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/root/infernet-container-starter"
  else
    TARGET_DIR="$HOME/infernet-container-starter"
  fi
  cd "$TARGET_DIR/projects/hello-world/contracts" || { echo "Contracts folder not found!"; return; }
  make call-contract
  read -p "Press Enter to return to menu..."
}

exit_program() {
  echo "Exiting Ritual Node One-Click Run..."
  exit 0
}

# Render the menu
print_menu() {
  clear
  echo "=== Ritual Node One-Click Run ==="
  echo "(Use ↑ ↓ to navigate, Enter to select, q to quit)"
  for i in "${!options[@]}"; do
    if [ $i -eq $selected ]; then
      echo -e "> \e[42;30m ${options[$i]} \e[0m"
    else
      echo "  ${options[$i]}"
    fi
  done
}

# === Main Loop ===
while true; do
  print_menu

  read -rsn1 key
  if [[ $key == $'\x1b' ]]; then
    read -rsn2 key
    case $key in
      '[A') # Up
        ((selected--))
        if [ $selected -lt 0 ]; then
          selected=$((${#options[@]} - 1))
        fi
        ;;
      '[B') # Down
        ((selected++))
        if [ $selected -ge ${#options[@]} ]; then
          selected=0
        fi
        ;;
    esac
  elif [[ $key == "" ]]; then
    case ${options[$selected]} in
      "Setup Node")                  setup_node ;;
      "Start Node")                  start_node ;;
      "Stop Node")                   stop_node ;;
      "Check Logs")                  check_logs ;;
      "Deploy Hello World Contract") deploy_hello_world_contract ;;
      "Call Hello World Contract")   call_hello_world_contract ;;
      "Exit")                        exit_program ;;
    esac
  elif [[ $key == "q" ]]; then
    exit_program
  fi
done
