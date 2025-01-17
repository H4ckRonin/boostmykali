#!/bin/bash

# Functie om te controleren of een programma geïnstalleerd is
is_installed() {
    local program="$1"
    
    # Controleren of het programma beschikbaar is via 'which' (voor binaire bestanden in $PATH)
    if command -v "$program" &> /dev/null; then
        echo "$program is al geïnstalleerd."
        return 0  # Het programma is geïnstalleerd
    else
        echo "$program is niet geïnstalleerd."
        return 1  # Het programma is niet geïnstalleerd
    fi
}

# Functie om te controleren of er updates beschikbaar zijn
check_updates() {
    echo "Controleren op updates..."

    # Voer een apt update uit zonder te upgraden, en filter alleen op 'upgradable' pakketten
    UPDATES=$(sudo apt update -qq | grep -i 'upgradable' | wc -l)

    if [ "$UPDATES" -gt 0 ]; then
        echo "Er zijn updates beschikbaar."
        return 1  # Er zijn updates beschikbaar
    else
        echo "Het systeem is al up-to-date."
        return 0  # Geen updates beschikbaar
    fi
}

# Functie om systeem bij te werken als er updates zijn
upgrade_system() {
    echo "Updates worden geïnstalleerd..."
    sudo apt upgrade -y
}

configure_git() {
    echo "Generate your new access token https://github.com/settings/tokens"
    echo ""
    echo "https://github.com/settings/tokens"
    echo "Note: SAVE YOUR ACCESS TOKEN"
    echo "Please enter your github username:"
    read -s github_username
    echo "Please enter your github password:"
    read -s github_password
    git config --global user.name $github_username
    git config --global user.email $github_password
    git config -l
    #incase you want to record your token git config --global credential.helper cache
    #git config --global --unset credential.helper
    #git config --system --unset credential.helper
}

# Functie om Codium te installeren
install_Codium() {
    echo "Codium installeren..."

    # Controleer of Codium al geïnstalleerd is
    if is_installed "Codium"; then
        echo "Codium is al geïnstalleerd, overslaan."
        return 0  # Als het al geïnstalleerd is, sla de installatie over
    fi

    wget https://github.com/VSCodium/vscodium/releases/download/1.96.3.25013/codium_1.96.3.25013_amd64.deb -O codium.deb

    # Installeer de laatste versie van Codium
    chmod +x codium.deb
    sudo dpkg -i codium.deb
}

# Functie om caido te installeren
install_caido() {
    echo "Caido installeren..."

    # Controleer of Caido al geïnstalleerd is
    if is_installed "caido"; then
        echo "Caido is al geïnstalleerd, overslaan."
        return 0  # Als het al geïnstalleerd is, sla de installatie over
    fi

    # Voeg de repository toe voor Codium
    wget https://caido.download/releases/v0.45.1/caido-desktop-v0.45.1-linux-x86_64.deb -O caido.deb

    # Installeer de laatste versie van Codium
    chmod +x caido.deb
    sudo dpkg -i caido.deb
}

# Functie om Oh My Zsh te installeren
install_oh_my_zsh(){
    if [ ! -d "$ZSH" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "Oh My Zsh is al geïnstalleerd."
    fi
}

# Functie voor andere tools installeren
install_other_tools() {
    echo "Andere tools installeren..."
    sudo apt install terminator timewarrior taskwarrior -y
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

# Functie voor hoofdmenu om keuze van de gebruiker te maken
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

EOF
    echo "Welkom bij de configuratie van je systeem!"
    echo "Wat wil je doen?"
    echo "1. Systeem bijwerken en upgrades uitvoeren"
    echo "2. Tools installeren (Codium, Caido, andere tools)"
    echo "3. Zsh plugins installeren en beheren"
    echo "4. Alles installeren (updates, tools en plugins)"
    echo "5. Git instellen"
    echo "6. BBH Tools installeren en API keys configureren"
    echo "7. Afsluiten"
    read -p "Kies een optie (1-7): " choice
    case $choice in
        1)
            check_updates
            if [ $? -eq 1 ]; then
                upgrade_system
            fi
            ;;
        2)
            install_Codium
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
            install_Codium
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
            api_bbh
            ;;
        7)
            echo "Afsluiten. Tot ziens!"
            exit 0
            ;;
        *)
            echo "Ongeldige keuze. Probeer het opnieuw."
            ;;
    esac
}

# Hoofdscript uitvoeren
show_main_menu