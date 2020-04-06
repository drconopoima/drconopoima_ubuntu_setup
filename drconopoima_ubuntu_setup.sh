#!/bin/bash -eu
# drconopoima_ubuntu_setup (v0.9.0)
# Quick from scratch setup script of an Ubuntu machine
# Optional Dependency: Auxiliary vimrc/bashrc/bash_aliases accompanying files
readonly SCRIPT_NAME='drconopoima_ubuntu_setup.sh'
readonly SCRIPT_VERSION='0.9.0'
readonly DEFAULT_PACKAGES='curl wget vim-gtk3 neovim bat'
packages=("${DEFAULT_PACKAGES}")

script_name() {
    printf "${SCRIPT_NAME}: (v${SCRIPT_VERSION})\n"
}

readonly -f script_name

usage_text() {
    printf "Usage: ${SCRIPT_NAME} ubuntu_version [--packages=*][--optional-flags: --google-chrome|--vscode]\n"
    printf "Example: ${SCRIPT_NAME} 20.04 --packages='neovim python-pip python3-pip'\n"
}

readonly -f usage_text

help_text() {
    usage_text
    printf "Options:\n"
    printf "    --packages=<list> list of packages to install in quotation marks\n"
    printf "    --google-chrome: Install google-chrome\n"
    printf "    --vscode: Install Visual Studio Code\n"
    printf "    --python-pip: Installs python-pip and python3-pip"
    printf "    --local-python=<user>: Installs python and pip to local user. Implies --python-pip\n"
    printf "    --remove-global-pip: Removes globally installed python-pip packages. Implies --python-pip\n"
}

readonly -f help_text

script_name

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
                --packages )
                    shift
                    packages=("$2")
                    skip_argument=1
                    ;;
                --google-chrome)
                    readonly GOOGLE_CHROME=1
                    shift # Remove --google-chrome from processing
                    ;;
                --vscode)
                    readonly VSCODE=1
                    shift # Remove --vscode= from processing
                    ;;
                --python-pip)
                    readonly PYTHON_PIP=1
                    shift
                    ;;
                --local-python=*)
                    readonly LOCAL_PYTHON=1
                    readonly PYTHON_USER="${argument#*=}"
                    shift # Remove --packages=* from processing
                    ;;
                --local-python )
                    shift
                    readonly LOCAL_PYTHON=1
                    readonly PYTHON_USER="$2"
                    skip_argument=1
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

apt-get update

apt-get upgrade -y

apt-get install -y ${packages[@]}


