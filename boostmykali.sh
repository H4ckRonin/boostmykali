#!/bin/bash

# Logbestand voor installaties
LOGFILE="/var/log/system_install.log"
exec > >(tee -a $LOGFILE) 2>&1

# Zet het script in 'strict mode' zodat het stopt bij fouten
set -euo pipefail  # Activeert strict mode: stop bij fouten, unset variabelen en pipeline fouten

# Functie om te loggen
log_message() {
    local message="$1"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $message"
}

handle_error() {
    local exit_code="$1"
    local line="$2"
    local command="$3"
    log_message "Error on line $line: Exit code $exit_code. Command: $command"
    exit "$exit_code"
}

trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

# Functie om te controleren of een programma is geïnstalleerd
is_installed() {
    local program="$1"
    command -v "$program" &> /dev/null
}

install_package() {
    local program="$1"
    local install_command="$2"
    
    log_message "Checking if $program is already installed..."
    if is_installed "$program"; then
        log_message "$program is already installed."
        return 0
    fi

    log_message "Downloading and installing $program..."
    
    # Gebruik apt-get om het programma te installeren
    sudo apt update -qq
    sudo apt install -y "$program"
    
    if [ $? -ne 0 ]; then
        log_message "Failed to install $program."
        return 1
    fi

    log_message "$program installed successfully."
    return 0
}

# Functie om systeemupdates te controleren en uit te voeren
check_and_upgrade() {
    log_message "Checking for updates..."

    # Voer 'apt update' uit om de lijst van beschikbare updates te vernieuwen
    sudo apt update -qq || { log_message "Failed to update package list."; return 1; }

    # Controleer of er updates beschikbaar zijn
    UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)

    if [ "$UPDATES" -gt 1 ]; then
        log_message "Updates are available."

        # Vraag de gebruiker of ze de updates willen uitvoeren
        read -p "Do you want to install the updates now? (y/n): " update_choice
        if [[ "$update_choice" == "y" || "$update_choice" == "Y" ]]; then
            log_message "Installing updates..."
            sudo apt upgrade --only-upgrade -y || { log_message "Failed to install updates."; return 1; }
            log_message "Updates installed successfully."
        else
            log_message "Skipping updates."
        fi

        # Vraag de gebruiker of ze de upgrades willen uitvoeren
        read -p "Do you want to upgrade the system now? (y/n): " upgrade_choice
        if [[ "$upgrade_choice" == "y" || "$upgrade_choice" == "Y" ]]; then
            log_message "Upgrading system..."
            sudo apt upgrade -y || { log_message "Failed to upgrade system."; return 1; }
            log_message "System upgraded successfully."
        else
            log_message "Skipping upgrade."
        fi
    else
        log_message "The system is already up-to-date."
    fi
}

# Functie om Git te configureren
configure_git() {
    read -p "Enter your name: " name
    read -p "Enter your email address: " email

    git config --global user.name "$name" || { log_message "Failed to configure Git name."; return 1; }
    git config --global user.email "$email" || { log_message "Failed to configure Git email."; return 1; }

    log_message "Git configuration set: Name: $name, Email: $email"
}

# Functie om Codium te installeren
install_codium() {
    local codium_url="https://github.com/VSCodium/vscodium/releases/download/1.96.3.25013/codium_1.96.3.25013_amd64.deb"
    install_package "Codium" "wget $codium_url -O codium.deb && sudo dpkg -i codium.deb" || return 1
}

# Functie om Caido te installeren
install_caido() {
    local caido_url="https://caido.download/releases/v0.45.1/caido-desktop-v0.45.1-linux-x86_64.deb"
    install_package "caido" "wget $caido_url -O caido.deb && sudo dpkg -i caido.deb" || return 1
}

restart_shell() {
    log_message "Restarting the shell to apply changes..."
    exec zsh
}

install_oh_my_zsh() {
    if [ ! -d "$ZSH" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || { log_message "Failed to install Oh My Zsh."; return 1; }
        log_message "Oh My Zsh installed."
        restart_shell  # Herstart de shell na installatie
    else
        log_message "Oh My Zsh is already installed."
    fi
}


# Functie om andere tools te installeren
install_other_tools() {
    local tools=("terminator" "timewarrior" "taskwarrior")
    for tool in "${tools[@]}"; do
        install_package "$tool" "sudo apt install -y $tool" || return 1
    done
}

install_bbh() {
    log_message "Bug Bounty Hunter Tools installeren..."

    # Functie om Go te controleren, versie te verkrijgen en te installeren
    log_message "Checking if Go is installed..."

    if command -v go &> /dev/null; then
        # Go is already installed, get the current version
        CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        log_message "Go is already installed. Current version: $CURRENT_GO_VERSION"
        
        log_message "Would you like to reinstall Go? (y/n)"
        read REINSTALL_GO
        
        # If the user does not want to reinstall Go, skip the Go installation
        if [[ "$REINSTALL_GO" != "y" ]]; then
            log_message "Skipping Go reinstallation."
            GO_SKIP=true  # Flag to indicate skipping Go installation
        else
            log_message "Proceeding with Go reinstallation..."
            GO_SKIP=false  # Flag to indicate proceeding with Go installation
        fi
    else
        log_message "Go is not installed. Proceeding with installation."
        GO_SKIP=false  # Flag to install Go if it's not installed
    fi

    # If the user opts to reinstall or Go is not installed, ask for the Go version
    if [[ "$GO_SKIP" == false ]]; then
        log_message "Type the version of Go you want to install (e.g., 1.19) or type 'directly' for the latest version:"
        read GOVERSION

        if [[ "$GOVERSION" == "directly" ]]; then
            log_message "You have chosen to install the latest version of Go."
            bash <(curl -sL https://git.io/go-installer) || { log_message "Failed to install Go."; return 1; }
        elif [[ ! "$GOVERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
            log_message "Invalid Go version format. Please enter a version in the format 'X.Y' (e.g., 1.19)."
            return 1
        else
            log_message "You have chosen Go version $GOVERSION."
            log_message "Downloading go-installer.sh..."
            wget https://git.io/go-installer.sh || { log_message "Failed to download go-installer.sh."; return 1; }
            chmod +x go-installer.sh
            bash go-installer.sh --version "$GOVERSION" || { log_message "Failed to install Go version $GOVERSION."; return 1; }
        fi
    fi

    # Install Bug Bounty Hunter tools
    log_message "Installing Bug Bounty Hunter Tools..."

    install_package() {
        local program="$1"
        local install_command="$2"

        log_message "Downloading and installing $program..."
        if ! sudo apt install -y $install_command; then
            log_message "Failed to install $program."
            return 1
        fi
        log_message "$program installed successfully."
    }

    install_package "golang" "golang" || return 1
    install_package "amass" "amass" || return 1
    install_package "subfinder" "subfinder" || return 1
    install_package "ffuf" "ffuf" || return 1
    install_package "feroxbuster" "feroxbuster" || return 1
    install_package "gobuster" "gobuster" || return 1
    install_package "dirbuster" "dirbuster" || return 1
    install_package "dirsearch" "dirsearch" || return 1

    # Install Project Discovery's Tool Manager
    log_message "Installing Project Discovery's Tool Manager"
    go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest || { log_message "Failed to install Project Discovery's Tool Manager."; return 1; }

    log_message "Now you have to type: source ~/.zshrc; pdtm --install-all"
}


# Functie om Bug Bounty Hunting API aanroepen te beheren
api_bbh() {
    log_message "Configuring your apikeys..."
    log_message "https://cloud.projectdiscovery.io/?ref=api_key"
    
    log_message "Please enter your PDCP API key:"
    read -s PDCP_API_KEY

    export PDCP_API_KEY
    log_message "ProjectDiscovery API key has been set successfully."

    install_package "libpcap-dev" "sudo apt install -y libpcap-dev" || return 1
    install_package "massdns" "sudo apt install -y massdns" || return 1
}

# Functie om een Zsh plugin te installeren
install_plugin() {
    local plugin_url=$1
    local plugin_name
    plugin_name=$(basename "$plugin_url" .plugin.zsh)
    log_message "Installing plugin $plugin_name from $plugin_url..."

    local plugin_dir="$ZSH_CUSTOM/plugins/$plugin_name"
    mkdir -p "$plugin_dir"
    curl -L "$plugin_url" -o "$plugin_dir/$plugin_name.plugin.zsh" || { log_message "Failed to download plugin $plugin_name."; return 1; }

    if [[ -f "$plugin_dir/$plugin_name.plugin.zsh" ]]; then
        log_message "$plugin_name installed successfully."
    else
        log_message "Failed to install $plugin_name."
        return 1
    fi
}

# Functie om plugins te beheren
manage_plugins() {
    local plugins=(
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-history-substring-search"
        "zsh-users/zsh-completions"
        "mrjohannchang/zsh-interactive-cd"
        "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/web-search/web-search.plugin.zsh"
    )

    for plugin in "${plugins[@]}"; do
        if [[ "$plugin" == https://* ]]; then
            install_plugin "$plugin" || return 1
        else
            plugin_name=$(basename "$plugin")
            if [[ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]]; then
                git clone "https://github.com/$plugin.git" "$ZSH_CUSTOM/plugins/$plugin_name" || { log_message "Failed to clone plugin $plugin_name."; return 1; }
            else
                log_message "$plugin_name is already installed."
            fi
        fi
    done
}

# Hoofdmenu van het script
show_main_menu() {
    clear
    cat <<EOF


    ⠀⠀⢀⣫⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡷⡀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢸⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⢳⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢰⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣦⣤⡶⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⢺⠀⠀⠀⠀
⢤⣤⢀⡀⣀⣼⣿⣤⣀⡀⠀⡀⣀⣀⣀⡀⢀⡀⠀⠀⠸⡟⠽⠟⠀⠀⠀⢀⡟⡛⢿⠛⢿⣿⣇⣀⠀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣯⠀⠀⠀⠀
⠀⠀⠀⠀⠉⢙⣿⡖⠀⠐⠒⠛⠊⠉⠁⠉⠉⠭⠕⠋⠛⠛⠿⠒⠒⠒⠒⣺⣽⣯⣿⣿⣿⣿⠽⠻⠿⠷⠾⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣟⣿⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠘⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡠⢤⠀⢋⡹⡜⢻⡟⢧⠇⠑⠀⠄⢀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣷⡃⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⣿⣣⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠎⠉⠉⠐⠈⠉⠁⠚⠧⣸⠛⠊⣹⠋⠁⣈⠋⠓⠤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣘⠇⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢥⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⢓⣸⣷⠍⠁⠀⠀⠀⠀⢸⠁⠀⡼⠁⠀⠐⠸⢵⣦⠤⣳⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣺⢃⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠘⣿⡃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣧⠄⡉⣿⣀⣀⠀⠀⠀⢀⣈⣄⣼⠀⠀⠀⣠⣀⣿⢫⣄⠈⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡿⣸⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡌⢀⠎⢹⡿⣿⡿⡶⠞⣋⠽⣟⠿⠫⢙⢶⣶⣷⣿⡿⣧⠀⠳⠙⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣇⡇⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢘⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠁⣎⣠⡟⠀⠹⣮⣒⣸⣁⡔⢀⡄⠀⠀⡼⢃⣹⡟⠀⠹⣧⡀⡁⠰⡀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠋⡤⣟⠋⠀⠀⢀⢾⢤⠝⡻⠬⠴⠣⠞⠉⡝⢣⢿⡅⠀⠀⠈⠻⣧⡀⠣⠀⠀⠀⠀⠀⠀⠀⠠⣏⡌⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢸⣷⠀⠀⠀⠀⠀⠀⠀⢁⢁⣿⡇⠀⠀⠀⣿⠾⣸⣀⣷⣀⣇⠀⢇⡀⣇⣸⣾⣿⠀⠀⠀⠀⣿⠷⠀⠀⠀⠀⠀⠀⠀⠀⢸⢷⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡀⠀⠀⠀⠀⡰⠀⢑⣣⡾⠀⠀⠀⠀⣟⡿⢸⡅⣳⠄⡆⢈⠆⠲⡷⣿⣿⣾⡀⠀⠀⠀⠸⣆⠁⠀⠡⠀⠀⠀⠀⢀⡿⡼⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢫⣧⠀⠀⠀⠠⠡⠂⣼⠏⠀⡤⣄⣴⣶⢿⣿⣿⡛⢶⠚⡤⢩⠛⣻⣽⣟⣿⠟⣹⢱⠄⠀⠀⠙⢧⡀⠀⠡⠀⠀⠀⣸⣿⠃⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⡄⠀⢀⠇⢁⡞⠁⠀⢰⣻⣮⣙⣯⣷⢣⡑⠭⣛⢿⣿⡿⣳⣿⣿⣿⣟⣫⣵⣾⢄⠀⠀⠀⠈⠳⣄⠠⢣⠀⠀⡟⡘⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⣗⡖⣳⣀⠟⠀⠀⣖⣻⣿⣿⣿⣿⢣⡣⣙⠦⣟⡿⠝⣹⣿⣿⣟⣿⣭⡛⠲⠶⠾⠷⢲⠀⠀⠀⠙⢦⣑⡓⣿⣷⡇⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⢴⠯⣽⣹⣯⡠⠤⣠⣽⣿⣿⣿⣿⣿⣧⣻⠾⡟⠛⣠⣿⣿⡿⣿⣿⡾⣼⣻⢼⣝⣒⣻⣉⣙⣆⣀⠀⠈⣿⣇⡿⢯⠾⠃⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣩⠿⣿⠃⢠⠞⢋⣬⣴⡟⢿⣿⣿⢿⡷⣿⣴⣿⣿⣿⣿⣿⡕⢽⡟⢶⣍⡊⠔⣋⡻⠽⢞⡻⢉⣆⠀⠳⣿⣷⠝⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠁⠀⠙⣿⣾⡃⠐⡱⠉⡸⡵⣈⢿⢮⣿⢿⣻⢻⢿⣿⣿⣿⢿⣿⣦⠈⠳⢄⡉⣉⣤⣴⢞⣽⣶⣿⣿⣅⢰⡽⠋⢀⣄⡺⣙⢢⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⢿⣯⠠⠚⠠⡐⠠⣁⠙⣌⣳⣿⣿⣌⠳⠾⠶⡚⢏⡯⢟⣭⡿⣦⣆⠼⠟⣫⣷⣿⣿⣿⣿⣿⣿⣿⣷⣾⡿⣞⣻⣟⡻⢷⡀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⡠⠈⣿⠇⢌⡱⣈⠵⣦⣹⣴⠏⣉⠥⠛⠓⢧⣱⡫⣝⣺⠿⣛⣹⣥⠾⢟⡛⡛⠥⢋⡙⢿⣿⣿⡷⣿⣯⣿⣽⣯⣭⣷⣿⣷⡇⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠔⢀⠠⠐⠠⢌⠲⡰⢥⣚⢯⣿⣽⣟⣟⣛⣛⡚⠒⠓⠓⢋⠉⡩⢌⣡⣄⠩⠦⡴⣥⣭⣦⣝⣢⠻⣿⣽⣷⣿⣿⣿⣿⡿⠿⠿⠟⠒⠐⠂⢤
⠀⠀⠀⠀⠀⠀⠠⢀⠐⠀⡀⠆⡰⣉⠼⡌⢧⡓⢧⢎⠯⣿⣞⡽⣟⠻⣿⡿⣿⣶⣯⣭⣵⣖⣲⠦⢬⣭⡵⣶⣄⣢⡐⠌⡡⢊⠌⣉⠋⠔⢠⠉⠷⡨⢦⣵⣤⣦⢤⡠⠏
⠀⠀⠀⠀⠀⠀⠠⠁⢀⠂⡜⣴⡱⣬⢧⣽⣷⣿⣿⣮⣷⣧⣞⣿⠨⡗⢠⠛⠶⣬⡙⠻⠿⣿⡿⢿⣷⣶⣶⣤⣴⣈⣉⠩⠑⠒⠰⠆⠬⣀⠂⠈⠄⡈⠁⢂⠉⠉⠉⠁⠂

Welcome to the system configuration!

What would you like to do?
1. Check for updates and perform upgrades
2. Install tools (Codium, Caido, other tools)
3. Install and manage Zsh plugins
4. Install everything (updates, tools, and plugins)
5. Configure Git
6. Configure Bug Bounty Hunting Tools
7. Exit
EOF
    read -p "Choose an option (1-7): " choice
    case $choice in
        1)
            check_and_upgrade
            ;;
        2)
            install_codium
            install_caido
            install_other_tools
            ;;
        3)
            manage_plugins
            ;;
        4)
            check_and_upgrade
            install_codium
            install_caido
            install_other_tools
            manage_plugins
            ;;
        5)
            configure_git
            ;;
        6)
            install_bbh
            api_bbh
            ;;
        7)
            log_message "Exiting. Goodbye!"
            exit 0
            ;;
        *)
            log_message "Invalid choice. Please try again."
            ;;
    esac
}

# Voer het hoofdmenu uit
show_main_menu
