#!/usr/bin/env bash
# drconopoima_ubuntu_setup (v1.2.1)
# Quick from scratch setup script of an Ubuntu machine
# Optional Dependency: Auxiliary vimrc/bashrc/bash_aliases accompanying files
# set -n
set -Eeuo pipefail
# Sourced from `man bash`
# set -E | set -o errtrace:  If set, any trap on ERR is inherited by shell functions
# set -u | set -o nounset: Treat unset variables and parameters (except "@" and "*") as an  error  when performing parameter expansion.
# set -e | set -o errexit: Exit immediately if a pipeline, a list, or  a  compound  command, exits with a non-zero status.
# set -o pipefail: If set, the return value of a pipeline is the value of the last command to exit with a non-zero status, or zero if all exit successfully.
# set -C | set -o noclubber: If set, bash does not overwrite an existing file with the >, >&,  and  <>  redirection operators. Overriden by >|
# Debugging flags:
# set -n | set -o noexec: Read  commands  but do not execute them. This may be used to check for syntax errors
# set -x | set -o xtrace: After  expanding  each command, display the value of PS4, followed by the command and its expanded arguments

# Additional ideas on bash scripting robustness:
# * David Phasley: https://www.davidpashley.com/articles/writing-robust-shell-scripts/
# * Tom Van Eyck: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

readonly SCRIPT_NAME="$0"
readonly SCRIPT_VERSION='1.2.1'

script_name() {
    printf "%s: (v%s)\n" "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
}

readonly -f script_name

script_name

readonly DEFAULT_PACKAGES_TO_INSTALL="curl wget vim-gtk3 neovim bat ufw git make \
build-essential bleachbit mpv flatpak smokeping nmap \
glances atop libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
libsqlite3-dev llvm libncurses5-dev libncursesw5-dev xz-utils libffi-dev \
liblzma-dev virtualbox vagrant virtualbox-ext-pack krita ibus \
netcat-openbsd snapd libnotify-bin hwinfo tcpdump gawk fonts-opensymbol \
plasma-workspace-wallpapers coreutils apt-file telnet openssh-client \
openssh-server gpg net-tools exfat-fuse jq tmux maven sqlite3 \
lsof colormake most nocache jpegoptim mmv qpdf rename postgresql \
asciinema fail2ban dsniff ecryptfs-utils cryptsetup mariadb-server mariadb-client \
zsh autojump dolphin-plugins postgresql-contrib innoextract \
bc module-assistant tldr fd-find imagemagick source-highlight \
command-not-found tree ncdu fzf aptitude p7zip-full python3-docutils traceroute \
iproute2 htop gddrescue libipmimonitoring-dev libjson-c-dev libmongoc-dev \
libsnappy-dev libprotobuf-dev libprotoc-dev protobuf-compiler libnfnetlink-dev \
libnetfilter-acct-dev uuid-dev gcc autoconf automake pkg-config smartmontools \
xfsdump sshpass linux-tools-generic wireshark ethtool tshark perf-tools-unstable \
bpfcc-tools sshpass pssh cgroup-tools pass libimage-exiftool-perl default-jre default-jdk \
kdenlive rbenv stress-ng glmark2 virt-manager virt-v2v"

readonly DEFAULT_SNAP_PACKAGES_INSTALL_CLASSIC="rustup go aws-cli google-cloud-cli"
readonly DEFAULT_SNAP_PACKAGES_INSTALL="shellcheck yq libreoffice k6 chromium"
readonly DEFAULT_FLATPAK_PACKAGES_INSTALL="com.heroicgameslauncher.hgl"

DEFAULT_PACKAGES_TO_REMOVE="gstreamer1.0-fluendo-mp3 telnetd"

packages_to_install=("${DEFAULT_PACKAGES_TO_INSTALL}")

packages_to_remove=("${DEFAULT_PACKAGES_TO_REMOVE}")

usage_text() {
    printf "Usage: %s <ubuntu_version> --user <username> [--packages=*][--optional-flags: --google-chrome|--vscode]\n" "${SCRIPT_NAME}"
    printf "Example: %s 20.04  --user <username> --packages='neovim golang bleachbit'\n" "${SCRIPT_NAME}"
}

readonly -f usage_text

help_text() {
    usage_text
    printf "Options:\n"
    printf "    --packages=<list> list of packages to install in quotation marks\n"
    printf "    --google-chrome: Install google-chrome\n"
    printf "    --vscode: Install Visual Studio Code\n"
    printf "    --vscode-insiders: Install Visual Studio Code Insiders \n"
    printf "    --python-pip: Installs python-pip and python3-pip\n"
    printf "    --local-pip=<user>: Installs pip locally to provided user. Implies --python-pip and --remove-global-pip.\n"
    printf "    --remove-global-pip: Removes globally installed python[3]-pip packages. Implies --python-pip and --local-pip.\n"
    printf "    --git: Installs git.\n"
    printf "    --git-name: Sets up global user name for git config. Implies --git. Requires --user=<system_user>.\n"
    printf "    --git-email: Sets up global user email for git config. Implies --git. Requires --user=<system_user>.\n"
    printf "    --clean-packages: List of packages to remove on top of default clean-up packages.\n"
    printf "    --extra-packages: List of additional packages to install on top of default packages.\n"
    printf "    --ufw: Install UFW firewall and set up the following default rules: deny incoming, allow outgoing, allow localhost 22, 3306 (mysql), 5432 (postgresql), 80 (http), 443 (https).\n"
    printf "    --docker-ce: Install Docker Community Edition (ensures removal of any docker dependency from APT package manager)\n"
    printf "    --calibre: Install Calibre EBook Reading Software.\n"
    printf "    --pyenv: Install Pyenv Python Version Management by using project pyenv-installer.\n"
    printf "    --user: Select user for configuration\n"
    printf "    --crystal: Install crystal programming language\n"
    printf "    --widevine: Install widevine DRM library for Chromium Browser (add Chromium to snap package list)\n"
}

readonly -f help_text

readonly NUMBER_OF_ARGUMENTS=$#

if [[ "${NUMBER_OF_ARGUMENTS}" -eq 0 ]]; then
    usage_text
    printf "Please provide an Ubuntu version as an argument.\n"
    exit 1
fi

readonly ALL_ARGUMENTS=("$@")
readonly ARGUMENT1="${ALL_ARGUMENTS[0]}"

# Print help on -h/--help
case "${ARGUMENT1}" in
-h | --help)
    help_text
    exit 0
    ;;
*)
    ubuntu_version="${argument}"
    ;;
esac

# Check for root user
if [[ "${EUID}" -ne 0 ]]; then
    printf "ERROR: This script needs to run as root.\n"
    exit 1
fi

readonly REST_ARGUMENTS=("${ALL_ARGUMENTS[@]:1}")

CONSTANTS=('GOOGLE_CHROME' 'VSCODE' 'VSCODE_INSIDERS' 'INSTALL_PYTHON_PIP' 'LOCAL_PIP' 'PYTHON_USER' 'INSTALL_GIT' 'GIT_USER_NAME' 'GIT_USER_EMAIL' 'REMOVE_GLOBAL_PIP' 'INSTALL_UFW' 'NEW_SSH_PORT' 'VALIDATE_SSH_PORT' 'DOCKER_CE' 'CALIBRE' 'pyenv' 'USERNAME' 'CRYSTAL' 'WIDEVINE')

skip_argument=0
if [[ "${NUMBER_OF_ARGUMENTS}" -gt 1 ]]; then
    # Process Command line arguments & flags.
    # Sources:
    # - @pretzelhands (Richard Blechinger): https://pretzelhands.com/posts/command-line-flags
    # - Shane Day: https://stackoverflow.com/a/24501190/6651552
    for argument in "${REST_ARGUMENTS[@]}"; do
        if [[ "${skip_argument}" -eq 0 ]]; then
            case ${argument} in
            # Handle --packages=value
            --packages=*)
                packages_to_install=("${argument#*=}")
                shift # Remove --packages=* from processing
                ;;
            # Handle --packages value
            --packages)
                shift
                packages_to_install=("$2")
                skip_argument=1
                ;;
            --google-chrome)
                GOOGLE_CHROME=1
                shift # Remove --google-chrome from processing
                ;;
            --docker-ce)
                DOCKER_CE=1
                shift
                ;;
            --calibre)
                CALIBRE=1
                shift
                ;;
            --vscode)
                VSCODE=1
                shift # Remove --vscode= from processing
                ;;
            --vscode-insiders)
                VSCODE_INSIDERS=1
                shift # Remove --vscode= from processing
                ;;
            --pyenv)
                PYENV=1
                shift
                ;;
            --python-pip)
                INSTALL_PYTHON_PIP=1
                shift
                ;;
            --local-pip=*)
                INSTALL_PYTHON_PIP=1
                REMOVE_GLOBAL_PIP=1
                LOCAL_PIP=1
                for user in ${argument#*=}; do
                    PYTHON_USER+=("$user")
                done
                shift # Remove --local-pip=* from processing
                ;;
            --local-pip)
                shift
                INSTALL_PYTHON_PIP=1
                REMOVE_GLOBAL_PIP=1
                LOCAL_PIP=1
                for user in $2; do
                    PYTHON_USER+=("$user")
                done
                skip_argument=1
                ;;
            --remove-global-pip)
                REMOVE_GLOBAL_PIP=1
                shift
                ;;
            --git)
                INSTALL_GIT=1
                shift
                ;;
            --git-name=*)
                INSTALL_GIT=1
                GIT_USER_NAME="${argument#*=}"
                shift
                ;;
            --git-name)
                shift
                INSTALL_GIT=1
                GIT_USER_NAME="$2"
                skip_argument=1
                ;;
            --git-email=*)
                INSTALL_GIT=1
                GIT_USER_EMAIL="${argument#*=}"
                shift
                ;;
            --git-email)
                shift
                INSTALL_GIT=1
                GIT_USER_EMAIL="$2"
                skip_argument=1
                ;;
            --clean-packages=*)
                for package in ${argument#*=}; do
                    packages_to_remove+=("$package")
                done
                shift
                ;;
            --clean-packages)
                shift
                for package in $2; do
                    packages_to_remove+=("$package")
                done
                skip_argument=1
                ;;
            --ssh-port=*)
                NEW_SSH_PORT="${argument#*=}"
                VALIDATE_SSH_PORT=1
                shift
                ;;
            --ssh-port)
                shift
                NEW_SSH_PORT="$2"
                VALIDATE_SSH_PORT=1
                skip_argument=1
                ;;
            --ufw)
                INSTALL_UFW=1
                shift
                ;;
            --user=*)
                USERNAME="${argument#*=}"
                shift
                ;;
            --user)
                shift
                USERNAME="$2"
                skip_argument=1
                ;;            
            --crystal)
                CRYSTAL=1
                shift
                ;;

            --widevine)
                WIDEVINE=1
                shift
                ;;
            *)
                echo "Error: unrecognized option ${argument#*=}"
                exit 1
                ;;
            esac
        else
            skip_argument=0
            continue
        fi
    done
fi

for constant in "${CONSTANTS[@]}"; do
    readonly "${constant}"
done

if [[ -n ${USERNAME+x} ]]; then
    HOMEDIR_USER="$(getent passwd "$USERNAME" | awk -F ':' '{print $6}')"
fi

if [[ -n ${GIT_USER_NAME+x} && -z ${USERNAME+x} || ${GIT_USER_EMAIL+x} && -z ${USERNAME+x} ]]; then
    echo "Argument Error: You need to specify a system user for whom to configure Git identity."
    exit 1
fi

if [[ -n ${VALIDATE_SSH_PORT+x} ]]; then
    number_regex='^[0-9]+$'
    if ! [[ $NEW_SSH_PORT =~ $number_regex ]]; then
        # Binary operator =~: the string to the right of the operator is a regular expression and  matched. The return value is 0 if the string matches the pattern, and 1 otherwise. If the regular expression is syntactically incorrect, the return value is 2. Same precedence as == and !=.
        echo "Warning: Input Error. New SSH port value '$NEW_SSH_PORT' is not numeric. Skipping changes to SSH port configuration." >&2
    elif [[ $NEW_SSH_PORT -eq 22 || ($NEW_SSH_PORT -gt 1024 && $NEW_SSH_PORT -lt 65535) ]]; then
        readonly CHANGE_SSH_PORT=1
    else
        echo "Warning: Input Error. New SSH port value '$NEW_SSH_PORT' is outside of valid range for SSH ports: 22,1025~65534. Skipping changes to SSH port configuration." >&2
    fi
fi

if [[ -n ${INSTALL_PYTHON_PIP+x} ]]; then
    if [[ "${ubuntu_version}" =~ 2[02].04 ]]; then
        packages_to_install+=('python2' 'python3-pip' 'python3-venv')
    else
        packages_to_install+=('python-pip' 'python3-pip' 'python3-venv')
    fi
fi

if [[ -n ${INSTALL_GIT+x} ]]; then
    packages_to_install+=('git')
fi

if [[ -n ${PYENV+x} ]]; then
    packages_to_install+=('make' 'build-essential' 'libssl-dev' 'zlib1g-dev' 'libbz2-dev' 'libreadline-dev' 'libsqlite3-dev' 'wget' 'curl' 'llvm' 'libncurses5-dev' 'xz-utils' 'libxml2-dev' 'libxmlsec1-dev' 'libffi-dev' 'liblzma-dev' 'tk-dev')
fi


if [[ -n ${REMOVE_GLOBAL_PIP+x} ]]; then
    if [[ "${ubuntu_version}" =~ 2[02].04 ]]; then
        packages_to_remove+=('python3-pip')
    else
        packages_to_remove+=('python-pip' 'python3-pip')
    fi
fi

if [[ -n ${INSTALL_UFW+x} ]]; then
    packages_to_install+=('ufw')
fi

if [[ -n ${VSCODE+x} || -n ${VSCODE_INSIDERS+x} || -n ${DOCKER_CE+x} || -n ${GOOGLE_CHROME+x} || -n ${CALIBRE+x} || -n ${WIDEVINE} || -n ${CRYSTAL} ]]; then
    packages_to_install+=('curl' 'coreutils' 'apt-transport-https' 'ca-certificates' 'wget' 'gnupg-agent' 'software-properties-common' 'xdg-utils' 'xz-utils' 'tk-dev')
fi

add-apt-repository universe
add-apt-repository multiverse

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y

# Accept Virtualbox License
if [[ " ${packages_to_install[*]} " =~ " virtualbox-ext-pack " ]]; then
    echo virtualbox-ext-pack virtualbox-ext-pack/license select true | debconf-set-selections
fi

DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages_to_install[@]}"

if [[ -n ${LOCAL_PIP+x} ]]; then
    if [[ "${ubuntu_version}" =~ 2[02].04 ]]; then
        sudo -u "$USERNAME" python3 -m pip install --user --upgrade pip
    fi
fi

if [[ -n ${INSTALL_GIT+x} ]]; then
    if [[ -n ${GIT_USER_NAME+x} ]]; then
        sudo -u "$USERNAME" git config --global user.name "${GIT_USER_NAME}"
    fi

    if [[ -n ${GIT_USER_EMAIL+x} ]]; then
        sudo -u "$USERNAME" git config --global user.email "${GIT_USER_EMAIL}"
    fi
fi

readonly SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
if [[ -e $SSHD_CONFIG_FILE ]]; then
    GREP_SSH_PORT_CONFIG=$(grep -E "^[[:space:]]*Port([[:space:]]*|[=]?)" $SSHD_CONFIG_FILE | awk '{$1=$1;print}')
    ## GNU/POSIX extensions to regular expressions. Source: Chapter 3 `sed` FAQ. http://sed.sourceforge.net/sedfaq3.html
    # [[:alnum:]]  - [A-Za-z0-9]     Alphanumeric characters
    # [[:alpha:]]  - [A-Za-z]        Alphabetic characters
    # [[:blank:]]  - [ \x09]         Space or tab characters only
    # [[:cntrl:]]  - [\x00-\x19\x7F] Control characters
    # [[:digit:]]  - [0-9]           Numeric characters
    # [[:graph:]]  - [!-~]           Printable and visible characters
    # [[:lower:]]  - [a-z]           Lower-case alphabetic characters
    # [[:print:]]  - [ -~]           Printable (non-Control) characters
    # [[:punct:]]  - [!-/:-@[-`{-~]  Punctuation characters
    # [[:space:]]  - [ \t\v\f]       All whitespace chars
    # [[:upper:]]  - [A-Z]           Upper-case alphabetic characters
    # [[:xdigit:]] - [0-9a-fA-F]     Hexadecimal digit characters
    readonly GREP_SSH_PORT_CONFIG
    if [[ -z ${GREP_SSH_PORT_CONFIG+x} ]]; then
        current_ssh_port=22
    elif [[ -z "${GREP_SSH_PORT_CONFIG##*'='*}" ]]; then
        # if configuration is set up with equal sign, e.g. Port=22
        current_ssh_port=$(echo "$GREP_SSH_PORT_CONFIG" | cut -d"=" -f2 | awk '{$1=$1;print}')
    else
        current_ssh_port=$(echo "$GREP_SSH_PORT_CONFIG" | awk '{print $2}')
    fi
fi

if [[ -n ${CHANGE_SSH_PORT+x} ]]; then
    if [[ -e $SSHD_CONFIG_FILE ]]; then
        :
    else
        echo "Warning: System Error. Could not find SSHD configuration file at '$SSHD_CONFIG_FILE'. Skipping changes to SSH port configuration." >&2
    fi
fi

readonly ufwsectionlockfile="/var/lock/$SCRIPT_NAME.ufw.lock"
if [[ -n ${INSTALL_UFW+x} ]]; then
    if (
        set -o noclobber
        echo "$$" >"$ufwsectionlockfile"
    ) 2>/dev/null; then
        trap 'rm -f '"$ufwsectionlockfile"'; exit $?' INT TERM EXIT
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        # SSH
        if [[ -n ${current_ssh_port+x} ]]; then
            ufw allow in on lo to 0.0.0.0 port "${current_ssh_port}"
            ufw allow out on lo to 0.0.0.0 port "${current_ssh_port}"
        else
            ufw allow in on lo to 0.0.0.0 port 22
            ufw allow out on lo to 0.0.0.0 port 22
        fi
        # HTTP
        ufw allow in on lo to 0.0.0.0 port 80
        ufw allow out on lo to 0.0.0.0 port 80
        # HTTPS
        ufw allow in on lo to 0.0.0.0 port 443
        ufw allow out on lo to 0.0.0.0 port 443
        # MySQL
        ufw allow in on lo to 0.0.0.0 port 3306
        ufw allow out on lo to 0.0.0.0 port 3306
        # PostgreSQL
        ufw allow in on lo to 0.0.0.0 port 5432
        ufw allow out on lo to 0.0.0.0 port 5432
        ufw --force disable
        ufw --force enable
        rm -f "$ufwsectionlockfile"
        trap - INT TERM EXIT
    else
        echo "Failed to acquire lockfile: Held by $ufwsectionlockfile."
    fi
fi

if [[ -n ${GOOGLE_CHROME+x} ]]; then
    TEMP_GOOGLE_CHROME_DEB="$(mktemp).deb"
    trap 'rm -f '"$TEMP_GOOGLE_CHROME_DEB"'; exit $?' INT TERM EXIT
    curl -qo "${TEMP_GOOGLE_CHROME_DEB}" 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' &&
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${TEMP_GOOGLE_CHROME_DEB}" &&
        rm -f "$TEMP_GOOGLE_CHROME_DEB"
    trap - INT TERM EXIT
fi

if [[ -n ${VSCODE+x} || -n ${VSCODE_INSIDERS+x} ]]; then
    curl -qs https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >archive_uri-https_packages_microsoft_com_keys_microsoft-asc.gpg
    install -o root -g root -m 644 archive_uri-https_packages_microsoft_com_keys_microsoft-asc.gpg /usr/share/keyrings/
    sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/archive_uri-https_packages_microsoft_com_keys_microsoft-asc.gpg arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/archive_uri-https_packages_microsoft_com_keys_microsoft-asc.list'
fi

if [[ -n ${VSCODE+x} ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y code
fi

if [[ -n ${VSCODE_INSIDERS+x} ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y code-insiders
fi

if [[ -n ${DOCKER_CE+x} ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get remove -y docker docker-engine docker.io containerd runc
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor | tee "/usr/share/keyrings/archive_uri-https_download_docker_com_linux_ubuntu-$(lsb_release -cs).gpg" 1>/dev/null
    sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/archive_uri-https_download_docker_com_linux_ubuntu-$(lsb_release -cs).gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu-$(lsb_release -cs).list'
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io
    if [[ -n ${USERNAME+x} ]]; then
        usermod --append --groups docker "$USERNAME"
    fi
fi

if [[ -n ${CALIBRE+x} ]]; then
    wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin install_dir=/opt
fi

if [[ -n ${PYENV+x} ]]; then
    curl -s -S -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash -e
fi

if [[ -n ${CRYSTAL+x} ]]; then
    # Download GPG Key from OpenSuse.org
    curl -fsSL "https://download.opensuse.org/repositories/devel:languages:crystal/xUbuntu_$(lsb_release -rs)/Release.key" | gpg --dearmor | tee "/etc/apt/trusted.gpg.d/archive_uri-https_download-opensuse-org_repositories_devel-languages-crystal_xUbuntu_$(lsb_release -rs | tr '.' '-')_Release-key.gpg" > /dev/null
    # Add repository
    echo "deb http://download.opensuse.org/repositories/devel:/languages:/crystal/xUbuntu_$(lsb_release -rs)/ /" | sudo tee "/etc/apt/sources.list.d/archive_uri-https_download-opensuse-org_repositories_devel-languages-crystal_xUbuntu_$(lsb_release -rs | tr '.' '-').list"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y crystal
fi

if [[ -n ${WIDEVINE+x} ]]; then
    # Get current version
    WIDEVINE_VERSION="$(curl -fsSL https://dl.google.com/widevine-cdm/current.txt)"
    readonly WIDEVINE_VERSION
    # Create chromium Library extensions folder
    mkdir -pv /usr/lib/chromium
    chmod -v 755 /usr/lib/chromium
    # Download Widevine SO

    # busybox unzip supports streaming extraction. See https://serverfault.com/questions/26474/unzipping-files-that-are-flying-in-through-a-pipe
    # tar supports streaming extraction
    ( (command -v busybox) && wget -nv -O- "https://dl.google.com/widevine-cdm/${WIDEVINE_VERSION}-linux-x64.zip" | busybox unzip -jo - libwidevinecdm.so -d /usr/lib/chromium ) ||
    ( (command -v jar) && ( pushd /usr/lib/chromium && wget -nv -O- "https://dl.google.com/widevine-cdm/${WIDEVINE_VERSION}-linux-x64.zip" | jar xv && rm manifest.json && rm LICENSE.txt && popd ) )
    chmod -v 644 /usr/lib/chromium/libwidevinecdm.so
fi
DEBIAN_FRONTEND=noninteractive apt-get remove -y "${packages_to_remove[@]}"
### setxkbmap
## Check current options
# setxkbmap -query
## Undo any previous options (pass empty argument list). Source https://unix.stackexchange.com/questions/229555/how-do-i-unset-an-option-in-xkbmap
## Set scroll lock as compose key
# list of key values here: https://gist.github.com/jatcwang/ae3b7019f219b8cdc6798329108c9aee
# list of pnemonic key combinations in: /usr/share/X11/locale/en_US.UTF-8/Compose
# or here: https://cgit.freedesktop.org/xorg/lib/libX11/tree/nls/en_US.UTF-8/Compose.pre
# Source with short explanation here: https://superuser.com/questions/74763/how-to-type-unicode-characters-in-kde/78724#78724
# Source with longer explanation here: http://canonical.org/~kragen/setting-up-keyboard.html
# Useful XCompose GitHub here: https://github.com/kragen/XCompose
if [[ -n ${USERNAME+x} ]]; then
    sudo -u "$USERNAME" /usr/bin/setxkbmap -option compose:lwin
    LINES_PROFILE=('# Enable custom Compose sequences on login' '/usr/bin/setxkbmap -option compose:lwin')
    for line in "${LINES_PROFILE[@]}"; do
        grep -qxF -- "$line" "${HOMEDIR_USER}/.profile" 2>/dev/null || echo "$line" >>"${HOMEDIR_USER}/.profile"
    done
    LINES_XCOMPOSE=('# This file defines custom Compose sequences for Unicode characters' '# Import default rules from the system Compose file:' 'include "/usr/share/X11/locale/en_US.UTF-8/Compose"')
    for line in "${LINES_XCOMPOSE[@]}"; do
        grep -qxF -- "$line" "${HOMEDIR_USER}/.XCompose" 2>/dev/null || echo "$line" >>"${HOMEDIR_USER}/.XCompose"
    done
    chown "$USERNAME:$USERNAME" "${HOMEDIR_USER}/.XCompose"
    chown "$USERNAME:$USERNAME" "${HOMEDIR_USER}/.profile"
fi
if [[ " ${packages_to_install[*]} " =~ " flatpak " ]]; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    if [[ -n ${USERNAME+x} ]]; then
        sudo -u "${USERNAME}" flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        sudo -u "${USERNAME}" flatpak install -y --user "${DEFAULT_FLATPAK_PACKAGES_INSTALL}"
    fi
    if [[ -n ${DEFAULT_FLATPAK_PACKAGES_INSTALL} ]]; then
        flatpak install -y "${DEFAULT_FLATPAK_PACKAGES_INSTALL}"
    fi
fi
if [[ -n ${DEFAULT_SNAP_PACKAGES_INSTALL_CLASSIC} ]]; then
    snap install --classic "${DEFAULT_SNAP_PACKAGES_INSTALL_CLASSIC}"
fi
if [[ $DEFAULT_SNAP_PACKAGES_INSTALL_CLASSIC =~ "helm" ]]; then
    snap run helm repo add stable https://kubernetes-charts.storage.googleapis.com/
fi
if [[ $DEFAULT_SNAP_PACKAGES_INSTALL_CLASSIC =~ "rustup" ]]; then
    sudo -u "$USERNAME" rustup install stable
    sudo -u "$USERNAME" rustup default stable
fi
if [[ -n ${DEFAULT_SNAP_PACKAGES_INSTALL} ]]; then
    snap install "${DEFAULT_SNAP_PACKAGES_INSTALL}"
fi
if [[ $DEFAULT_SNAP_PACKAGES_INSTALL =~ "shellcheck" ]]; then
    ln -s -T /snap/bin/shellcheck /usr/bin/shellcheck;
fi
## Apache Example: batch apply atomic changes in directory
# cp -a /var/www /var/www-tmp
# find /var/www-tmp -type f -name "*.html" -print0 | xargs -0 perl -pi -e 's/.conf/.com/'
# mv /var/www /var/www-old
# mv /var/www-tmp /var/www
# Apache opens the files on every request, otherwise processes should be restarted to apply changes
