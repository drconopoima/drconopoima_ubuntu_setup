#!/usr/bin/env bash
# drconopoima_ubuntu_setup (v0.9.0)
# Quick from scratch setup script of an Ubuntu machine
# Optional Dependency: Auxiliary vimrc/bashrc/bash_aliases accompanying files
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
libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
python-openssl virtualbox vagrant virtualbox-ext-pack krita ibus \
netcat-openbsd snapd libnotify-bin hwinfo tcpdump gawk fonts-opensymbol \
kubuntu-restricted-extras kubuntu-restricted-addons kubuntu-wallpapers \
plasma-workspace-wallpapers coreutils apt-file telnet openssh-client \
openssh-server gpg net-tools exfat-fuse exfat-utils jq tmux maven sqlite3 \
lsof colormake most calibre"

DEFAULT_PACKAGES_TO_REMOVE="gstreamer1.0-fluendo-mp3 telnetd"

packages_to_install=("${DEFAULT_PACKAGES_TO_INSTALL}")

packages_to_remove=("${DEFAULT_PACKAGES_TO_REMOVE}")

usage_text() {
    printf "Usage: ${SCRIPT_NAME} <ubuntu_version> --user <username> [--packages=*][--optional-flags: --google-chrome|--vscode]\n"
    printf "Example: ${SCRIPT_NAME} 20.04  --user <username> --packages='neovim golang bleachbit'\n"
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
    printf "    --user: Select user for configuration\n"
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

CONSTANTS=('GOOGLE_CHROME' 'VSCODE' 'INSTALL_PYTHON_PIP' 'LOCAL_PIP' 'PYTHON_USER' 'INSTALL_GIT' 'GIT_USER_NAME' 'GIT_USER_EMAIL' 'REMOVE_GLOBAL_PIP' 'INSTALL_UFW' 'NEW_SSH_PORT' 'VALIDATE_SSH_PORT')

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

HOMEDIR_USER="$(getent passwd $USERNAME | awk -F ':' '{print $6}')"

for constant in ${CONSTANTS[@]}; do
    readonly ${constant}
done

if [[ -n ${VALIDATE_SSH_PORT+x} ]]; then
    number_regex='^[0-9]+$'
    if ! [[ $NEW_SSH_PORT =~ $number_regex ]]; then
    # Binary operator =~: the string to the right of the operator is a regular expression and  matched. The return value is 0 if the string matches the pattern, and 1 otherwise. If the regular expression is syntactically incorrect, the return value is 2. Same precedence as == and !=.
        echo "Warning: Input Error. New SSH port value '$NEW_SSH_PORT' is not numeric. Skipping changes to SSH port configuration." >&2;
    elif [[ $NEW_SSH_PORT -eq 22 || ( $NEW_SSH_PORT -gt 1024 && $NEW_SSH_PORT -lt 65535 ) ]]; then
        readonly CHANGE_SSH_PORT=1; 
    else
        echo "Warning: Input Error. New SSH port value '$NEW_SSH_PORT' is outside of valid range for SSH ports: 22,1025~65534. Skipping changes to SSH port configuration." >&2;
    fi
fi

if [[ -n ${INSTALL_PYTHON_PIP+x} ]]; then
    packages_to_install+=('python-pip' 'python3-pip')
fi

if [[ -n ${INSTALL_PYTHON_PIP+x} ]]; then
    packages_to_install+=('git')
fi

if [[ -n ${REMOVE_GLOBAL_PIP+x} ]]; then
    packages_to_remove+=('python-pip' 'python3-pip')
fi

if [[ -n ${INSTALL_UFW+x} ]]; then
    packages_to_install+=('ufw')
fi

if [[ -n ${GOOGLE_CHROME+x} ]]; then
    packages_to_install+=('curl')
fi

if [[ -n ${VSCODE+x} ]]; then
    packages_to_install+=('curl coreutils apt-transport-https')
fi

add-apt-repository universe

apt-get update

apt-get full-upgrade -y

DEBIAN_FRONTEND=noninteractive apt-get install -y ${packages_to_install[@]}

if [[ -n ${GIT_USER_NAME+x} ]]; then
    git config --global user.name "${GIT_USER_NAME}"
fi

if [[ -n ${GIT_USER_EMAIL+x} ]]; then
    git config --global user.email "${GIT_USER_EMAIL}"
fi

readonly SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
if [[ -e $SSHD_CONFIG_FILE ]]; then
    GREP_SSH_PORT_CONFIG=$(grep -E "^[[:space:]]*Port([[:space:]]*|[=]?)" $SSHD_CONFIG_FILE | awk '{$1=$1;print}');
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
        current_ssh_port=22;
    elif [[ -z "${GREP_SSH_PORT_CONFIG##*'='*}" ]]; then
        # if configuration is set up with equal sign, e.g. Port=22
        current_ssh_port=$(echo "$GREP_SSH_PORT_CONFIG"| cut -d"=" -f2 | awk '{$1=$1;print}')
    else
        current_ssh_port=$(echo "$GREP_SSH_PORT_CONFIG"| awk '{print $2}')
    fi
fi

if [[ -n ${CHANGE_SSH_PORT+x} ]]; then
    if [[ -e $SSHD_CONFIG_FILE ]]; then
        :
    else
        echo "Warning: System Error. Could not find SSHD configuration file at '$SSHD_CONFIG_FILE'. Skipping changes to SSH port configuration." >&2;
    fi
fi

readonly ufwsectionlockfile="/var/lock/$SCRIPT_NAME.ufw.lock";
if [[ -n ${INSTALL_UFW+x} ]]; then
    if ( set -o noclobber; echo "$$" > "$ufwsectionlockfile") 2> /dev/null; then
        trap "rm -f '$ufwsectionlockfile'; exit $?" INT TERM EXIT
        ufw --force reset
        ufw default block incoming
        ufw default allow outgoing
        # SSH
        if [[ -n ${current_ssh_port+x} ]]; then
            ufw allow to 0.0.0.0 port ${current_ssh_port} from 127.0.0.1
        else
            ufw allow to 0.0.0.0 port 22 from 127.0.0.1
        fi
        # HTTP
        ufw allow to 0.0.0.0 port 80 from 127.0.0.1
        # HTTPS
        ufw allow to 0.0.0.0 port 443 from 127.0.0.1
        # MySQL
        ufw allow to 0.0.0.0 port 3306 from 127.0.0.1
        # PostgreSQL
        ufw allow to 0.0.0.0 port 5432 from 127.0.0.1
        ufw --force disable
        ufw --force enable
        rm -f $ufwsectionlockfile
        trap - INT TERM EXIT
    else
        echo "Failed to acquire lockfile: Held by $ufwsectionlockfile." 
    fi
fi

if [[ -n ${GOOGLE_CHROME+x} ]]; then
    TEMP_GOOGLE_CHROME_DEB="$(mktemp).deb"
    trap "rm -f '$TEMP_GOOGLE_CHROME_DEB'; exit $?" INT TERM EXIT
    curl -qo "${TEMP_GOOGLE_CHROME_DEB}" 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' &&
    apt install -y "${TEMP_GOOGLE_CHROME_DEB}" &&
    rm -f $TEMP_GOOGLE_CHROME_DEB
    trap - INT TERM EXIT
fi

if [[ -n ${VSCODE+x} ]]; then
    curl -q https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
    sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
    apt update
    apt install -y vscode
fi

DEBIAN_FRONTEND=noninteractive apt-get remove -y ${packages_to_remove[@]}

### setxkbmap
## Check current options
# setxkbmap -query
## Undo any previous options (pass empty argument list). Source https://unix.stackexchange.com/questions/229555/how-do-i-unset-an-option-in-xkbmap
sudo -u $USERNAME /bin/bash -c "PATH='/usr/bin:$PATH'; setxkbmap -option "
## Set scroll lock as compose key
# list of key values here: https://gist.github.com/jatcwang/ae3b7019f219b8cdc6798329108c9aee
# list of pnemonic key combinations in: /usr/share/X11/locale/en_US.UTF-8/Compose
# or here: https://cgit.freedesktop.org/xorg/lib/libX11/tree/nls/en_US.UTF-8/Compose.pre
# Source with short explanation here: https://superuser.com/questions/74763/how-to-type-unicode-characters-in-kde/78724#78724
# Source with longer explanation here: http://canonical.org/~kragen/setting-up-keyboard.html 
# Useful XCompose GitHub here: https://github.com/kragen/XCompose
sudo -u $USERNAME /bin/bash -c "PATH='/usr/bin:$PATH'; setxkbmap -option compose:rctrl"
echo "# This file defines custom Compose sequences for Unicode characters" > "${HOMEDIR_USER}/.XCompose"
echo "# Import default rules from the system Compose file:" >> "${HOMEDIR_USER}/.XCompose"
echo "include \"/usr/share/X11/locale/es_ES.UTF-8/Compose\"" >> "${HOMEDIR_USER}/.XCompose"
chown $USERNAME:$USERNAME "${HOMEDIR_USER}/.XCompose"

## Apache Example: batch apply atomic changes in directory
# cp -a /var/www /var/www-tmp
# find /var/www-tmp -type f -name "*.html" -print0 | xargs -0 perl -pi -e 's/.conf/.com/'
# mv /var/www /var/www-old
# mv /var/www-tmp /var/www
# Apache opens the files on every request, otherwise processes should be restarted to apply changes
