#!/bin/bash

# Function to check if a program is installed
is_installed() {
    local program="$1"
    
    # Check if the program is available using 'which' (for binaries in $PATH)
    if command -v "$program" &> /dev/null; then
        echo "$program is already installed."
        return 0  # Program is installed
    else
        echo "$program is not installed."
        return 1  # Program is not installed
    fi
}

# Function to check if updates are available
check_updates() {
    echo "Checking for updates..."

    # Run an apt update without upgrading, and filter only 'upgradable' packages
    UPDATES=$(sudo apt update -qq | grep -i 'upgradable' | wc -l)

    if [ "$UPDATES" -gt 0 ]; then
        echo "Updates are available."
        return 1  # Updates are available
    else
        echo "The system is already up-to-date."
        return 0  # No updates available
    fi
}

# Function to upgrade the system if updates are available
upgrade_system() {
    echo "Installing updates..."
    sudo apt upgrade -y
}

# Function to configure git
configure_git() {
  read -p "Enter your name: " name
  read -p "Enter your email address: " email

  git config --global user.name "$name"
  git config --global user.email "$email"

  echo "Git configuration set:"
  echo "Name: $name"
  echo "Email: $email"
}

# Function to install Codium
install_codium() {
    echo "Installing Codium..."

    # Check if Codium is already installed
    if is_installed "Codium"; then
        echo "Codium is already installed, skipping."
        return 0  # If it's already installed, skip installation
    fi

    wget https://github.com/VSCodium/vscodium/releases/download/1.96.3.25013/codium_1.96.3.25013_amd64.deb -O codium.deb

    # Install the latest version of Codium
    chmod +x codium.deb
    sudo dpkg -i codium.deb
}

# Function to install Caido
install_caido() {
    echo "Installing Caido..."

    # Check if Caido is already installed
    if is_installed "caido"; then
        echo "Caido is already installed, skipping."
        return 0  # If it's already installed, skip installation
    fi

    # Add the repository for Codium
    wget https://caido.download/releases/v0.45.1/caido-desktop-v0.45.1-linux-x86_64.deb -O caido.deb

    # Install the latest version of Caido
    chmod +x caido.deb
    sudo dpkg -i caido.deb
}

# Function to install Oh My Zsh
install_oh_my_zsh(){
    if [ ! -d "$ZSH" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "Oh My Zsh is already installed."
    fi
}

# Function to install other tools
install_other_tools() {
    echo "Installing other tools..."
    sudo apt install terminator timewarrior taskwarrior -y
}

# Function to install plugins
install_plugin() {
    local plugin_url=$1
    local plugin_name
    # Extract the plugin name from the URL (strip the path and extension)
    plugin_name=$(basename "$plugin_url" .plugin.zsh)
    echo "Installing plugin $plugin_name from $plugin_url..."

    # Define the plugin directory
    local plugin_dir="$ZSH_CUSTOM/plugins/$plugin_name"

    # Create the plugin directory if it doesn't exist
    mkdir -p "$plugin_dir"

    # Download the raw plugin file from the provided URL and save it without the .plugin.zsh extension
    curl -L "$plugin_url" -o "$plugin_dir/$plugin_name.plugin.zsh"

    # Check if the plugin was downloaded successfully
    if [[ -f "$plugin_dir/$plugin_name.plugin.zsh" ]]; then
        echo "$plugin_name successfully installed!"
    else
        echo "Failed to install $plugin_name!"
    fi
}

# Function to remove plugins
remove_plugin() {
    local plugin_name=$1
    echo "Removing $plugin_name..."

    # Remove the plugin directory
    rm -rf "$ZSH_CUSTOM/plugins/$plugin_name"

    # Check if the plugin was removed successfully
    if [[ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]]; then
        echo "$plugin_name successfully removed!"
    else
        echo "Failed to remove $plugin_name!"
    fi
}

# Function to update ~/.zshrc with the installed plugins
update_zshrc() {
    echo "Updating ~/.zshrc with the installed plugins..."
    
    # Get the current list of plugins in ~/.zshrc
    current_plugins=$(grep -oP '(?<=^plugins=\()[^\)]+' ~/.zshrc)

    # Add plugins to ~/.zshrc if they aren't already there
    for plugin in "${plugins[@]}"; do
        plugin_name=$(basename "$plugin" .plugin.zsh) # Remove .plugin.zsh from the plugin name
        if [[ ! "$current_plugins" =~ "$plugin_name" ]]; then
            sed -i "/^plugins=(/s/)/ $plugin_name )/" ~/.zshrc
            echo "Added $plugin_name to ~/.zshrc"
        fi
    done

    # Remove plugins from ~/.zshrc that are no longer in the list
    for plugin in $(echo "$current_plugins" | tr ' ' '\n'); do
        if [[ ! " ${plugins[@]} " =~ " $plugin " ]]; then
            sed -i "/^plugins=(/s/ $plugin//" ~/.zshrc
            echo "Removed $plugin from ~/.zshrc"
        fi
    done
}

# Function to manage plugins (install/remove)
manage_plugins() {
    # Define the plugins you want to install or remove (including the raw plugin URL)
    plugins=(
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-history-substring-search"
        "zsh-users/zsh-completions"
        "mrjohannchang/zsh-interactive-cd"
        "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/web-search/web-search.plugin.zsh"
    )

    # Install plugins
    for plugin in "${plugins[@]}"; do
        if [[ "$plugin" == https://* ]]; then
            install_plugin "$plugin"
        else
            plugin_name=$(basename "$plugin")
            if [[ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]]; then
                git clone "https://github.com/$plugin.git" "$ZSH_CUSTOM/plugins/$plugin_name"
            else
                echo "$plugin_name is already installed."
            fi
        fi
    done

    # Update ~/.zshrc with the list of installed plugins
    update_zshrc

    echo "Plugins are installed and ~/.zshrc is updated."
}

install_bbh() {
    echo "Bug Bounty Hunter Tools installeren..."
    
    # Install required packages
    sudo apt install golang amass subfinder ffuf feroxbuster gobuster dirbuster dirsearch -y
    
    # Ask for Go version
    echo "Type the version of Go you want to install (1.19 or leave blank for latest recommended):"
    read GOVERSION
    
    # If Go version is provided, download and run the installer script with the specified version
    if [ -n "$GOVERSION" ]; then
        # Download the installer script
        echo "Downloading go-installer.sh..."
        wget https://git.io/go-installer.sh
        chmod +x go-installer.sh
        # Run the installer script with the specified version
        bash go-installer.sh --version "$GOVERSION"
    else
        # If no version is provided, use curl to run the script directly
        echo "Running go-installer.sh directly..."
        bash <(curl -sL https://git.io/go-installer)
    fi
    
    # Install Project Discovery's Tool Manager
    echo "Installing Project Discovery's Tool Manager"
    go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest
    
    # Final instructions
    echo "Now you have to type: source ~/.zshrc; pdtm --install-all"
}

api_bbh(){
    echo "Configuring your apikeys..."
    echo "https://cloud.projectdiscovery.io/?ref=api_key"
    # Prompt the user to enter their API key
    echo "Please enter your PDCP API key:"
    read -s PDCP_API_KEY

    # Export the API key
    export PDCP_API_KEY

    # Confirmation message
    echo "ProjectDiscovery API key has been set successfully."
#    cvemap -auth
#    asnmap -auth
    sudo apt install -y libpcap-dev massdns
}

# Main menu function to allow user choice
show_main_menu() {
    clear
    cat << EOF


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
    read -p "Choose an option (1-6): " choice
    case $choice in
        1)
            check_updates
            if [ $? -eq 1 ]; then
                upgrade_system
            fi
            ;;
        2)
            install_codium
            install_caido
            install_other_tools
            ;;
        3)
            manage_plugins
            sudo update-alternatives --set x-www-browser /usr/bin/firefox-esr
            ;;
        4)
            check_updates
            if [ $? -eq 1 ]; then
                upgrade_system
            fi
            install_codium
            install_caido
            install_other_tools
            manage_plugins
            sudo update-alternatives --set x-www-browser /usr/bin/firefox-esr
            ;;
        5)
            configure_git
            ;;
        6)  
            install_bbh
            wait
            api_bbh
            ;;
        7)
            echo "Exiting. Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
}

# Run the main menu script
show_main_menu

