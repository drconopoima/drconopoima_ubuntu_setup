#!/usr/bin/env bash
# drconopoima_ubuntu_setup (v0.9.0)
# Quick from scratch setup script of an Ubuntu machine
# Optional Dependency: Auxiliary vimrc/bashrc/bash_aliases accompanying files
set -euo pipefail

readonly SCRIPT_NAME='drconopoima_ubuntu_setup.sh'
readonly SCRIPT_VERSION='0.9.0'

script_name() {
    printf "${SCRIPT_NAME}: (v${SCRIPT_VERSION})\n"
}

readonly -f script_name

script_name

# Check for root user
if [[ "${EUID}" -ne 0 ]]; then
    printf "ERROR: This script needs to run as root.\n"
    exit 1
fi

readonly DEFAULT_PACKAGES_TO_INSTALL="curl wget vim-gtk3 neovim bat ufw git make \
build-essential default-jdk default-jre bleachbit vlc flatpak \
chromium-browser glances atop docker.io docker-compose golang \
libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl \
llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
python-openssl virtualbox vagrant virtualbox-ext-pack krita ibus \
netcat-openbsd snapd libnotify-bin hwinfo tcpdump gawk fonts-opensymbol \
kubuntu-restricted-extras kubuntu-restricted-addons kubuntu-wallpapers \
plasma-workspace-wallpapers coreutils apt-file telnet openssh-client \
openssh-server"

DEFAULT_PACKAGES_TO_REMOVE="gstreamer1.0-fluendo-mp3 telnetd"

packages_to_install=("${DEFAULT_PACKAGES_TO_INSTALL}")

packages_to_remove=("${DEFAULT_PACKAGES_TO_REMOVE}")

usage_text() {
    printf "Usage: ${SCRIPT_NAME} <ubuntu_version> [--packages=*][--optional-flags: --google-chrome|--vscode]\n"
    printf "Example: ${SCRIPT_NAME} 20.04 --packages='neovim golang bleachbit'\n"
}

readonly -f usage_text

help_text() {
    usage_text
    printf "Options:\n"
    printf "    --packages=<list> list of packages to install in quotation marks\n"
    printf "    --google-chrome: Install google-chrome\n"
    printf "    --vscode: Install Visual Studio Code\n"
    printf "    --python-pip: Installs python-pip and python3-pip\n"
    printf "    --local-pip=<user>: Installs pip locally to provided user. Implies --python-pip and --remove-global-pip.\n"
    printf "    --remove-global-pip: Removes globally installed python[3]-pip packages. Implies --python-pip and --local-pip.\n"
    printf "    --git: Installs git.\n"
    printf "    --git-name: Sets up global user name for git config. Implies --git.\n"
    printf "    --git-email: Sets up global user email for git config. Implies --git.\n"
    printf "    --clean-packages: List of packages to remove on top of default clean-up packages.\n"
    printf "    --extra-packages: List of additional packages to install on top of default packages.\n"
    printf "    --ufw: Install UFW firewall and set up the following default rules: deny incoming, allow outgoing, allow localhost 22, 3306 (mysql), 5432 (postgresql), 80 (http), 443 (https).\n"
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
for argument in "${ARGUMENT1}"
do
    case "${argument}" in
        -h|--help)
            help_text
            exit 0
        ;;
        *)
            ubuntu_version="${argument}"
        ;;
    esac
done

readonly REST_ARGUMENTS=("${ALL_ARGUMENTS[@]:1}")

CONSTANTS=('GOOGLE_CHROME' 'VSCODE' 'INSTALL_PYTHON_PIP' 'LOCAL_PIP' 'PYTHON_USER' 'INSTALL_GIT' 'GIT_USER_NAME' 'GIT_USER_EMAIL' 'REMOVE_GLOBAL_PIP' 'INSTALL_UFW')

skip_argument=0
if [[ "${NUMBER_OF_ARGUMENTS}" -gt 1 ]]; then
    # Process Command line arguments & flags. 
    # Sources:
    # - @pretzelhands (Richard Blechinger): https://pretzelhands.com/posts/command-line-flags
    # - Shane Day: https://stackoverflow.com/a/24501190/6651552
    for argument in "${REST_ARGUMENTS[@]}"
    do
        if [[ "${skip_argument}" -eq 0 ]]; then
            case ${argument} in
                # Handle --packages=value
                --packages=*)
                    packages=("${argument#*=}")
                    shift # Remove --packages=* from processing
                    ;;
                # Handle --packages value
                --packages)
                    shift
                    packages=("$2")
                    skip_argument=1
                    ;;
                --google-chrome)
                    GOOGLE_CHROME=1
                    shift # Remove --google-chrome from processing
                    ;;
                --vscode)
                    VSCODE=1
                    shift # Remove --vscode= from processing
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
                        PYTHON_USER+=($user)
                    done
                    shift # Remove --local-pip=* from processing
                    ;;
                --local-pip)
                    shift
                    INSTALL_PYTHON_PIP=1
                    REMOVE_GLOBAL_PIP=1
                    LOCAL_PIP=1
                    for user in $2; do
                        PYTHON_USER+=($user)
                    done
                    skip_argument=1
                    ;;
                --remove-global-pip )
                    REMOVE_GLOBAL_PIP=1
                    shift
                    ;;
                --git )
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
                        packages_to_remove+=($package)
                    done
                    shift
                    ;;
                --clean-packages)
                    shift
                    for package in $2; do
                        packages_to_remove+=($package)
                    done
                    skip_argument=1
                    ;;
                --ufw)
                    INSTALL_UFW=1
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

for constant in ${CONSTANTS[@]}; do
    readonly ${constant}
done

if [[ ! -z ${INSTALL_PYTHON_PIP+x} ]]; then
    packages_to_install+=('python-pip' 'python3-pip')
fi

if [[ ! -z ${INSTALL_PYTHON_PIP+x} ]]; then
    packages_to_install+=('git')
fi

if [[ ! -z ${REMOVE_GLOBAL_PIP+x} ]]; then
    packages_to_remove+=('python-pip' 'python3-pip')
fi

if [[ ! -z ${INSTALL_UFW+x} ]]; then
    packages_to_install+=('ufw')
fi

apt-get update

apt-get full-upgrade -y

DEBIAN_FRONTEND=noninteractive apt-get install -y ${packages_to_install[@]}

if [[ ! -z GIT_USER_NAME ]]; then
    git config --global user.name "${GIT_USER_NAME}"
fi

if [[ ! -z GIT_USER_EMAIL ]]; then
    git config --global user.email "${GIT_USER_EMAIL}"
fi

if [[ ! -z ${INSTALL_UFW+x} ]]; then
    ufw --force reset
    ufw --force default block incoming
    ufw --force default allow outgoing
    ufw --force allow from 127.0.0.1 to 127.0.0.1 port 22 proto tcp
    ufw --force allow from 127.0.0.1 to 127.0.0.1 port 80 proto tcp
    ufw --force allow from 127.0.0.1 to 127.0.0.1 port 443 proto tcp
    ufw --force allow from 127.0.0.1 to 127.0.0.1 port 3306 proto tcp
    ufw --force allow from 127.0.0.1 to 127.0.0.1 port 5432 proto tcp
    ufw --force disable
    ufw --force enable
fi

DEBIAN_FRONTEND=noninteractive apt-get remove -y ${packages_to_remove[@]}
