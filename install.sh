#!/bin/bash

# Function to display a Zenity dialog with status message
display_status() {
    local zenity_pid=$(pgrep -f "zenity --info --text=")

    # If a Zenity dialog is found, kill it
    if [ -n "$zenity_pid" ]; then
        kill "$zenity_pid" >/dev/null 2>&1
    fi

    # Display the new status message
    zenity --info --text="$1" --title="Status" &
    echo $1 | tee /tmp/install.log --append
}

# Function to install and upgrade system packages
install_and_upgrade_packages() {
    display_status "Installing and upgrading packages..."
    sudo apt-get update && sudo apt-get upgrade -y  && sudo apt-get autoremove -y # || display_status "Failed to update and install packages."
    display_status "Packges installed and upgraded."
}

# Function to set up SSH folder with correct permissions
setup_ssh() {
    display_status "Configuring SSH folder..."
    mkdir -p ~/.ssh/ && chmod 700 ~/.ssh/  || display_status "Failed to configure SSH folder."
    display_status "SSH folder configured."
}

# Function to install CascadiaCode nerd font
install_cascadia_font() {
    display_status "Installing Cascadia font..."
    mkdir -p ~/CascadiaCode && cd ~/CascadiaCode || { display_status "Failed to create CascadiaCode font folder."; return 1; }
    curl -o CascadiaCode.zip -L https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip || { display_status "Failed to to download CascadiaCode."; return 1; }
    unzip -q CascadiaCode.zip || { display_status "Failed to unzip CascadiaCode."; return 1; }
    sudo mv *.ttf /usr/share/fonts/truetype/ || { display_status "Failed move font files to /usr/share/fonts/truetype/."; return 1; }
    rm -rf ~/CascadiaCode
    display_status "Cascadia font installed."
}

# Function to install Starship for terminal
install_starship_terminal() {
    display_status "Installing Starship Terminal..."
    curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes && echo 'eval "$(starship init bash)"' | tee -a ~/.bashrc
    display_status "Starship Terminal installed."
}

# Function to update GNOME Terminal settings
update_gnome_terminal_settings() {
    display_status "Updating GNOME Terminal settings..."
    profile=$(gsettings get org.gnome.Terminal.ProfilesList default | xargs echo)
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/ font 'CaskaydiaCove Nerd Font Mono 12'  || { display_status "Failed to set GNOME Terminal font."; return 1; }
    display_status "GNOME Terminal settings updated."
}

# Remove old git folder in case of OS refresh to avoid conflicts
remove_old_git_repos() {
    display_status "Removing old Git repositories..."
    rm -rf ~/git/xpadneo ~/git/avra ~/git/avrdude ~/git/tio || { display_status "Failed to remove old git folders."; return 1; }
    display_status "Old Git repositories removed."
}

# Function to install Git repos and software
install_git_repos_and_software() {
    display_status "Installing Git repositories and software..."
    mkdir -p ~/git && cd ~/git || { display_status "Failed to create git folder."; return 1; }

    # Install xpad neo
    sudo apt-get -y install dkms linux-headers-$(uname -r) || { display_status "Failed to xpadneo requirenments."; return 1; }
    git clone https://github.com/atar-axis/xpadneo.git && cd xpadneo || { display_status "Failed to clone xpadneo repo."; return 1; }
    sudo ./install.sh || { display_status "Failed to install xpadneo."; return 1; }

    # Install AVRA
    cd ~/git
    git clone https://github.com/Ro5bert/avra.git && cd avra || { display_status "Failed to clone arva repo."; return 1; }
    sudo make install || { display_status "Failed to install arva."; return 1; }

    # Install avrdude
    cd ~/git
    sudo apt-get -y install build-essential git cmake flex bison libelf-dev libusb-dev libhidapi-dev libftdi1-dev libreadline-dev libserialport-dev || { display_status "Failed to install avrdude requirenments."; return 1; }
    git clone https://github.com/avrdudes/avrdude.git && cd avrdude || { display_status "Failed to clone avrdude repo."; return 1; }
    sudo ./build.sh && sudo cmake --build build_linux --target install || { display_status "Failed to install avrdude."; return 1; }

    # Install tio
    cd ~/git
    sudo apt-get -y install liblua5.4-dev meson
    git clone git@github.com:tio/tio.git && cd ~/git/tio || { display_status "Failed to clone tio repo."; return 1; }
    sudo meson setup build
    sudo meson compile -C build
    sudo meson install -C build

    display_status "Git repositories and software installed."

}

# Function to add GPG keys and return the path to the keyring
add_gpg_key() {
    local url=$1
    local filename=$2
    local keyring="/usr/share/keyrings/${filename}.gpg"

    # Remove old GPG key if exists
    if [ -f "$keyring" ]; then
        sudo rm "$keyring"
    fi

    # Download the GPG key
    wget -qO- "$url" | sudo gpg --dearmor -o "$keyring"

    # Check if key was successfully added
    if [ $? -eq 0 ]; then
        # display_status "GPG key added successfully to: $keyring"
        echo "$keyring"
    else
        display_status "Failed to add GPG key."
        exit 1
    fi
}

# Function to add source files for APT repositories
add_source_file() {
    local file__name=$1
    local source_type=$2
    local url=$3
    local distribution=$4
    local components=$5
    local arch=$6
    local keyring=$7

    # Remove old source file if exists
    if [ -f "/etc/apt/sources.list.d/${file__name}.sources" ]; then
        sudo rm "/etc/apt/sources.list.d/${file__name}.sources"
    fi

    # Add new source file
    sudo tee "/etc/apt/sources.list.d/${file__name}.sources" > /dev/null <<EOF
Types: $source_type
URIs: $url
Suites: $distribution
Components: $components
$(if [ -n "$arch" ]; then echo "Architectures: $arch"; fi)
$(if [ -n "$keyring" ]; then echo "Signed-By: $keyring"; fi)

EOF
# X-Repolib-ID: $file__name
# X-Repolib-Name: $file__name
# Enabled: yes
}

install_apt_sources() {
    # Prepare for installation of gpg keys
    sudo apt-get install -y wget gnupg lsb-release apt-transport-https ca-certificates || { display_status "Failed to gpg requirenments."; return 1; }
    # Install dependencies
    # - libsecret-1-dev (Mailspring)
    # - libxcb-cursor0 (Calibre)
    # - qt6-base-dev (MikTex console)
    sudo apt-get install -y libsecret-1-dev libxcb-cursor0 qt6-base-dev || { display_status "Failed to dependencies."; return 1; }

    # TODO: Felhantering
    
    # Add source for Librewolf
    echo "Librewolf"
    local distro=$(if echo " una bookworm vanessa focal jammy bullseye vera uma " | grep -q " $(lsb_release -sc) "; then lsb_release -sc; else echo focal; fi)
    local gpg_librewolf=$(add_gpg_key "https://deb.librewolf.net/keyring.gpg" "librewolf")
    add_source_file "librewolf" "deb" "https://deb.librewolf.net" "$distro" "main" "amd64" "$gpg_librewolf"

    # Add source for Spotify
    echo "Spotify"
    local gpg_spotify=$(add_gpg_key "https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg" "spotify")
    add_source_file "spotify" "deb" "http://repository.spotify.com" "stable" "non-free" "amd64" "$gpg_spotify"

    # Add source for Miktex
    echo "Miktex"
    local gpg_miktex=$(add_gpg_key "https://miktex.org/download/key" "miktex")
    add_source_file "miktex" "deb" "https://miktex.org/download/ubuntu" "jammy" "universe" "amd64" "$gpg_miktex"

    # Add source for Sublime Tex and Sublime Merge
    echo "Sublime"
    local gpg_sublime=$(add_gpg_key "https://download.sublimetext.com/sublimehq-pub.gpg" "sublimehq-archive")
    add_source_file "sublime" "deb" "https://download.sublimetext.com/" "apt/stable/" "" "amd64" "$gpg_sublime"

    # Add source for Virtual box
    echo "Virtual box"
    local gpg_virtualbox=$(add_gpg_key "https://www.virtualbox.org/download/oracle_vbox_2016.asc" "oracle-virtualbox-2016")
    add_source_file "virtualbox" "deb" "https://download.virtualbox.org/virtualbox/debian" "jammy" "contrib" "amd64" "$gpg_virtualbox"

    # Add source for Signal
    echo "Signal"
    local gpg_signal=$(add_gpg_key "https://updates.signal.org/desktop/apt/keys.asc" "signal-desktop-keyring")
    add_source_file "signal" "deb" "https://updates.signal.org/desktop/apt" "xenial" "main" "amd64" "$gpg_signal"

    # Add source for JDK 17 LTS (Temurin)
    echo "JDK"
    local version=$(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release)
    local gpg_temurin_17=$(add_gpg_key "https://packages.adoptium.net/artifactory/api/gpg/key/public" "adoptium")
    add_source_file "adoptium" "deb" "https://packages.adoptium.net/artifactory/deb" "$version" "main" "amd64" "$gpg_temurin_17"

    # Run all apt installations
    sudo apt-get update && sudo apt-get install -y librewolf \
                                                   spotify-client \
                                                   miktex \
                                                   keepassxc \
                                                   sublime-text \
                                                   sublime-merge \
                                                   virtualbox \
                                                   signal-desktop \
                                                   temurin-17-jdk \
                                                   libsecret-tools \
                                                   fprintd \
                                                   libpam-fprintd \
                                                    || { display_status "Failed to apt software."; return 1; }
}

install_flatpak() {
    # Install Gear Lever via flatpak
    flatpak install flathub it.mijorus.gearlever || { display_status "Failed to install Gear Lever."; return 1; }
}

# Function to install software via deb files
install_as_deb() {
    local name=$1
    local url=$2

    curl -L -o $name $url
    wait $!
    sudo dpkg -i $name
    rm $name
}

install_deb() {
    # Install Steam
    install_as_deb "steam.deb" "https://cdn.akamai.steamstatic.com/client/installer/steam.deb" || { display_status "Failed to install Steam."; return 1; }

    # Install MailSpring
    install_as_deb "mailspring.deb" "https://updates.getmailspring.com/download?platform=linuxDeb" || { display_status "Failed to install MailSpring."; return 1; }

    # Install Discord
    install_as_deb "discord.deb" "https://discord.com/api/download?platform=linux&format=deb" || { display_status "Failed to install Discord."; return 1; }
}

install_ppa() {
    # Install KeePassXC
    sudo add-apt-repository ppa:phoerious/keepassxc -y || { display_status "Failed to add KeePassXC PPA."; return 1; }
}

# Function to append text to user's .bashrc
append_to_bashrc() {
    echo $1 | tee ~/.bashrc --append
}

install_script() {
    # Install Calibre
    wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin || { display_status "Failed to install Calibre."; return 1; }

    # Install rclone
    curl https://rclone.org/install.sh | sudo bash || { display_status "Failed to install rclone."; return 1; }

    # Install mcfly (improved reverse search in terminal)
    curl -LSfs https://raw.githubusercontent.com/cantino/mcfly/master/ci/install.sh | sudo sh -s -- --git cantino/mcfly || { display_status "Failed to mcfly."; return 1; }
    append_to_bashrc 'eval "$(mcfly init bash)"'

    # Install OVPN VPN client
    url="https://www.ovpn.com/sv/guides/ubuntu"
    link="https://files.ovpn.com/client/new-updates/linux/ubuntu-qt6/release/repo/OVPN-linux-"
    html=$(curl -s "$url")
    link2=$(echo "$html" | grep -o '<a [^>]*href="[^"]*"' | grep $link | sed 's/<a [^>]*href="\([^"]*\)"/\1/')
    curl -L -o ovpn.run $link2 || { display_status "Failed to download OVPN."; return 1; }
    wait $!
    chmod +x ovpn.run
    ./ovpn.run || { display_status "Failed to install OVPN."; return 1; }
}

# Function to install miscellaneous software
install_miscellaneous_software() {
    display_status "Installing miscellaneous software..."

    install_apt_sources
    install_deb
    install_ppa
    install_script

    display_status "Miscellaneous software installed."
}

configure_sublime_text() {
    display_status "Configuring sublime..."

    # Fix mouse scroll multie line select for Sublime Text
    mkdir -p ~/.config/sublime-text/Packages/User/
    tee ~/.config/sublime-text/Packages/User/Default\ \(Linux\).sublime-mousemap << EOF > /dev/null
[
    // Mouse 3 column select
    {
        "button": "button3",
        "press_command": "drag_select",
        "press_args": {"by": "columns"}
    },
    {
        "button": "button3", "modifiers": ["ctrl"],
        "press_command": "drag_select",
        "press_args": {"by": "columns", "additive": true}
    },
    {
        "button": "button3", "modifiers": ["alt"],
        "press_command": "drag_select",
        "press_args": {"by": "columns", "subtractive": true}
    }
]
EOF

    # Fix mouse scroll multie line select for Sublime Text (root user)
    sudo mkdir -p /root/.config/sublime-text/Packages/User/
    sudo tee /root/.config/sublime-text/Packages/User/Default\ \(Linux\).sublime-mousemap << EOF > /dev/null
[
    // Mouse 3 column select
    {
        "button": "button3",
        "press_command": "drag_select",
        "press_args": {"by": "columns"}
    },
    {
        "button": "button3", "modifiers": ["ctrl"],
        "press_command": "drag_select",
        "press_args": {"by": "columns", "additive": true}
    },
    {
        "button": "button3", "modifiers": ["alt"],
        "press_command": "drag_select",
        "press_args": {"by": "columns", "subtractive": true}
    }
]
EOF

    display_status "Sublime configured."
}

# Function to add custom keybinding
add_custom_keybinding() {
    local name=$1
    local command=$2
    local binding=$3

    # Check if the keybinding already exists
    local keys=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    local new_key="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$name/"
    if [[ ! $keys =~ $new_key ]]; then
        keys=${keys%\']}
        keys="$keys', '$new_key']"
        gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$keys" || { display_status "Failed to add custom keybinding."; return 1; }
    fi

    # Set custom keybinding
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$name/ name "$name" || { display_status "Failed to set name for custom keybinding."; return 1; }
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$name/ command "$command" || { display_status "Failed to set command for custom keybinding."; return 1; }
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$name/ binding "$binding" || { display_status "Failed to set binding for custom keybinding."; return 1; }
}


disable_brltty() {
    sudo systemctl stop brltty-udev.service || { display_status "Failed to stop service brltty-udev."; return 1; }
    sudo systemctl mask brltty-udev.service || { display_status "Failed to mask service brltty-udev."; return 1; }
    sudo systemctl stop brltty.service || { display_status "Failed to stop service brltty."; return 1; }
    sudo systemctl disable brltty.service || { display_status "Failed to disable service brltty."; return 1; }
}

set_aliases() {
    # Set alias for echo
    echo "alias e='echo'" | tee ~/.bashrc --append

    # Set py alias to point to python3
    sudo update-alternatives --install /usr/bin/py py /usr/bin/python3 1 || { display_status "Failed to update "; return 1; }
}

remove_autostarts() {
    # Remove Geary from autostart
    rm /home/$USER/.config/autostart/geary-autostart.desktop 2>/dev/null
}

remove_password_req_for_sudo() {
    local command=$1
    echo "$USER ALL = (ALL:ALL) NOPASSWD: $command" | sudo tee /etc/sudoers.d/$USER --append > /dev/null
}

add_keepass_password_to_keychain() {
    # Add KeePass's database password to keychain (enables KeePassXC to read keychain to unlock via keychain)
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then # XDG_CURRENT_DESKTOP is set
        zenity --entry --title "KeePassXC" --text "Skriv in lösenord:" | secret-tool store --label "KeePass" application keepassxc
    else # XDG_CURRENT_DESKTOP is not set
        secret-tool store --label "KeePass" application keepassxc
    fi
}

# Function to configure various settings
configure_settings() {
    # Configure mouse pointer settings for Sublime Text
    configure_sublime_text

    # Add custom key bindings
    add_custom_keybinding 'OVPN' '/opt/OVPN/OVPN' '<Super>i'
    add_custom_keybinding 'terminal' "/home/$USER/.local/bin/terminal" 'Print'
    add_custom_keybinding 'keepass' "/home/$USER/.local/bin/keepass" '<Super>k'

    # Add user to dialout group
    sudo adduser $USER dialout

    # Disable Barille (BRLTTY) - messes with ttyUSB devices
    disable_brltty

    # Set aliases
    set_aliases
    
    # Remove autostarts
    remove_autostarts

    # Remove password requirements for some commands when sudoing
    exempt_command_from_sudo_password "/usr/bin/cat"
    exempt_command_from_sudo_password "/usr/bin/nano"
    exempt_command_from_sudo_password "/usr/bin/subl"
    exempt_command_from_sudo_password "/usr/sbin/reboot"
    exempt_command_from_sudo_password "/usr/bin/tail"
    exempt_command_from_sudo_password "/usr/bin/ls"
    exempt_command_from_sudo_password "/usr/bin/systemctl"
    exempt_command_from_sudo_password "/usr/bin/cp"
    exempt_command_from_sudo_password "/usr/bin/mv"
    exempt_command_from_sudo_password "/usr/bin/find"
    exempt_command_from_sudo_password "/usr/bin/apt"
    exempt_command_from_sudo_password "/usr/bin/tee"
    exempt_command_from_sudo_password "/usr/bin/touch"

    # Prompt for enabling fingerprint auth
    sudo pam-auth-update
    
    # Add KeePass's database password to keychain
    add_keepass_password_to_keychain
}

# Function to run all actions
run_all() {
    # Call all individual functions sequentially
    install_and_upgrade_packages
    setup_ssh
    install_cascadia_font
    install_starship_terminal
    update_gnome_terminal_settings
    remove_old_git_repos
    install_git_repos_and_software
    install_miscellaneous_software
    configure_settings
}

display_menu() {
    zenity --list --title="Meny" --text="Välj en åtgärd:" --column="Val" \
    "1.  Installera och uppgradera paket" \
    "2.  Konfigurera SSH-mapp" \
    "3.  Installera Cascadia-fonten" \
    "4.  Installera Starship Terminal" \
    "5.  Uppdatera GNOME Terminalinställningar" \
    "6.  Ta bort gamla Git-repositorier" \
    "7.  Installera Git-repositorier och programvara" \
    "8.  Installera diverse programvara" \
    "9.  - Installera apt käller" \
    "10. - Installera deb" \
    "11. - Installera PPA" \
    "12. - Installera script" \
    "13. Konfigurera inställningar" \
    "14. Gör allt" \
    --width=350 --height=370
}


# Main function to handle user interaction and execute selected actions
main() {
    sudo -v
    while true; do
        choice=$(display_menu | cut -d '.' -f 1) # Call the display_menu function and store the user's choice
        case $choice in
            1) install_and_upgrade_packages ;;  # Call the appropriate function based on the user's choice
            2) setup_ssh ;;
            3) install_cascadia_font ;;
            4) install_starship_terminal ;;
            5) update_gnome_terminal_settings ;;
            6) remove_old_git_repos ;;
            7) install_git_repos_and_software ;;
            8) install_miscellaneous_software ;;
            9) install_apt_sources ;;
            10) install_deb ;;
            11) install_ppa ;;
            12) install_script ;;
            13) configure_settings ;;
            14) run_all ;;
            *) echo "Exiting the program. Goodbye!"; exit ;;  # Exit the script if the user chooses to exit
            # *) display_status "Invalid choice. Please try again." ;;  # Display an error message for invalid choices
        esac
    done
}

# Run the main function
main

