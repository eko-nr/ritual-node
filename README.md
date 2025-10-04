# Ritual Node One-Click Installation

This script provides an automated setup and management tool for running a Ritual Node using the Infernet Container Starter.

## System Requirements

- **CPU**: 4 cores (minimum)
- **RAM**: 4 GB (minimum)
- **Storage**: 700 GB (estimated, may require more)
- **OS**: Ubuntu 22.04 or higher (Docker compatible)
- **Network**: Stable internet connection

## Prerequisites

The script will automatically install the following if not already present:
- Docker
- Docker Compose
- Git
- jq (JSON processor)
- Foundry (Ethereum development toolkit)

## Installation

1. Clone the repository and setup:
```bash
git clone https://github.com/eko-nr/ritual-node && \
cd ritual-node && \
chmod +x start.sh
```

2. Run the script:
```bash
bash start.sh
```

## Menu Options

The script provides an interactive menu with the following options:

### 1. Setup Node

This is the initial setup process that configures your Ritual Node environment.

**Steps during setup:**

1. **Docker Installation**: Automatically installs Docker and Docker Compose if not present
2. **Repository Cloning**: Downloads the `infernet-container-starter` repository
3. **Hello World Container**: Deploys the hello-world container in the background
4. **Configuration Prompts**: You'll be asked to provide:
   
   - **RPC URL**: Your blockchain RPC endpoint (default: `https://mainnet.base.org`)
   - **Private Key**: Your wallet's private key (use a throwaway wallet for testing)
     - Must be 64 hex characters
     - Script will add `0x` prefix if missing
     - Demo key provided if left empty (NOT for production)
   
   - **SENDER Address**: Your wallet address (must start with `0x`)
     - Must be exactly 40 hex characters after `0x`
   
   - **Docker Hub Credentials**: Your Docker Hub username and password
   
   - **Snapshot Sync Configuration**:
     - `sleep` (default: 3)
     - `batch_size` (default: 50)
     - `sync_period` (default: 30)
   
   - **Registry Address**: Smart contract registry address (default: `0x3B1554f346DFe5c482Bb4BA31b880c1C18412170`)

5. **Foundry Installation**: Installs the Foundry toolkit for smart contract deployment

**Important**: The setup process updates configuration files, docker-compose settings, and Makefile with your provided credentials.

### 2. Start Node

Starts the Ritual Node using Docker Compose. This option:
- Pulls the latest hello-world container image
- Builds and starts all required containers in detached mode
- Node will run in the background

### 3. Stop Node

Gracefully stops the Ritual Node and all associated containers.

### 4. Check Logs

Opens a live log stream from the running Ritual Node. Useful for:
- Monitoring node activity
- Debugging issues
- Verifying successful operations
- Press `Ctrl+C` to exit log view

### 5. Deploy Hello World Contract

Deploys the Hello World smart contract to the blockchain.

**Process:**
1. Installs necessary Foundry dependencies
2. Cleans previous builds
3. Deploys the `SaysGM` contract
4. **Returns the deployed contract address** (save this for later use)

### 6. Call Hello World Contract

Interacts with a previously deployed Hello World contract.

**Steps:**
1. Enter the contract address (from deployment step)
   - Default: `0x13D69Cf7d6CE4218F646B759Dcf334D82c023d8e`
2. Script calls the `sayGM()` function on the contract
3. Executes the transaction on-chain

### 7. Exit

Exits the script.

## Quick Start Guide

1. **Initial Setup**:
   ```bash
   ./ritual-node.sh
   # Select "Setup Node" from menu
   # Follow all prompts and provide required information
   ```

2. **Start Your Node**:
   ```bash
   # Select "Start Node" from menu
   ```

3. **Verify Operation**:
   ```bash
   # Select "Check Logs" from menu
   # Verify node is running correctly
   # Press Ctrl+C to return to menu
   ```

4. **Deploy Contract** (Optional):
   ```bash
   # Select "Deploy Hello World Contract" from menu
   # Note the contract address from output
   ```

5. **Call Contract** (Optional):
   ```bash
   # Select "Call Hello World Contract" from menu
   # Enter your contract address when prompted
   ```

## Navigation

- Use `↑` and `↓` arrow keys to navigate menu
- Press `Enter` to select an option
- Press `q` to quit
- Press `Ctrl+C` to cancel operations

## Important Notes

- **Security**: Use a throwaway wallet for testing. Never use your main wallet's private key
- **RPC Provider**: Ensure your RPC provider supports the required network
- **Storage**: Monitor disk usage as blockchain data grows over time
- **Updates**: The script uses `latest` Docker images for up-to-date software

## Troubleshooting

**Docker issues:**
```bash
sudo systemctl status docker
sudo systemctl restart docker
```

**Permission errors:**
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

**Container not starting:**
```bash
# Check logs for errors
docker logs <container_name>
```

**Port conflicts:**
```bash
# Check if ports are already in use
sudo netstat -tulpn | grep <port_number>
```

## File Locations

- **Root user**: `/root/infernet-container-starter`
- **Regular user**: `$HOME/infernet-container-starter`
- **Config files**: `deploy/config.json` and `projects/hello-world/container/config.json`
- **Docker Compose**: `deploy/docker-compose.yaml`
- **Contracts**: `projects/hello-world/contracts/`

## Support

For issues and questions:
- Visit: [Ritual Network GitHub](https://github.com/ritual-net/infernet-container-starter)
- Documentation: Check official Ritual Network documentation

## License

This script manages the Infernet Container Starter. Please refer to the original repository for licensing information.