#!/bin/bash

# Funzione per calcolare il punteggio
calculateScore() {
    IFS='.' read -r -a wanted <<< "$1"
    IFS='.' read -r -a latest <<< "$2"
    score=0

    # major version = 100 points
    score=$(( (latest[0] - wanted[0]) * 100 ))
    
    # if major version is the same, check minor version
    if [ "$score" -le 0 ]; then
        # minor version = 10 points
        score=$(( (latest[1] - wanted[1]) * 10 ))
    fi
    
    # if minor version is the same, check patch version
    if [ "$score" -le 0 ]; then
        # patch version = 1 point
        score=$(( (latest[2] - wanted[2]) ))
    fi

    # Ensure score is not negative
    [ "$score" -lt 0 ] && score=0

    echo "$score"
}

# Funzione per calcolare i punteggi e aggiornare il totale
calculateOutdatedness() {
    local outdated_file=$1
    local type=$2
    local package
    local wanted
    local latest

    # Parsing del file JSON
    if [ "$type" == "composer" ]; then
        outdated_packages=$(jq -r '.installed[] | @base64' "$outdated_file")
    elif [ "$type" == "npm" ]; then
        outdated_packages=$(jq -r 'to_entries[] | @base64' "$outdated_file")
    fi

    echo "Calculating scores..."
    for row in $outdated_packages; do
        _jq() {
            echo "${row}" | base64 --decode | jq -r "${1}"
        }

        if [ "$type" == "composer" ]; then
            package=$(_jq '.name')
            wanted=$(_jq '.version')
            latest=$(_jq '.latest')
        elif [ "$type" == "npm" ]; then
            package=$(_jq '.key')
            wanted=$(_jq '.value.wanted')
            latest=$(_jq '.value.latest')
        fi

        # Pulizia delle versioni
        wanted=$(echo "$wanted" | sed 's/[^0-9.]//g')
        latest=$(echo "$latest" | sed 's/[^0-9.]//g')

        if [ "$debug" -eq 1 ]; then
            echo "Package: $package"
            echo "Wanted: $wanted"
            echo "Latest: $latest"
        fi

        score=$(calculateScore "$wanted" "$latest")

        if [ "$debug" -eq 1 ]; then
            echo "Score: $score"
            echo "-----------------"
        fi

        if [ "$score" -gt 0 ]; then
            scoringPackages+=("$package: $score")
        fi

        totalScore=$((totalScore + score))
    done
}

# Funzione per visualizzare l'usage
usage() {
    echo "Usage: $0 [-d] [-p project_path] [-h]"
    echo "  -d                Enable debug mode"
    echo "  -p project_path   Specify the project path (default is current directory)"
    echo "  -h                Show this help message"
    exit 0
}

totalScore=0
scoringPackages=()
debug=0
project_path="."

# Parsing degli argomenti
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--debug)
      debug=1
      echo "Debug mode enabled"
      shift # passa all'argomento successivo
      ;;
    -p|--path)
      project_path="$2"
      shift # passa all'argomento successivo
      shift # passa al valore successivo
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Invalid option: $1" 1>&2
      usage
      ;;
  esac
done

# se è stata specificata una directory, assicurati che esista
if [ "$project_path" != "." ] && [ ! -d "$project_path" ]; then
    echo "Directory not found: $project_path"
    exit 1
fi
if [ "$project_path" != "." ]; then
    echo "Project path: $project_path"
fi
cd "$project_path" || exit

# Controllo per Composer
if [ -f composer.json ]; then
    echo "Installing Composer packages..."
    if [ "$debug" -eq 1 ]; then
        composer install
    else
        composer install --quiet > /dev/null 2>&1
    fi

    echo "Checking for outdated Composer packages..."
    composer outdated --direct --format=json > composer-outdated.json
    calculateOutdatedness "composer-outdated.json" "composer"

    # Rimuovi il file
    rm -f composer-outdated.json
fi

# Controllo per NPM
if [ -f package.json ]; then
    echo "Installing NPM packages..."

    # se esiste il comando nvm e il file .nvmrc, usa la versione di Node.js specificata
    if command -v nvm &> /dev/null && [ -f .nvmrc ]; then
        nvm use
    fi

    if [ "$debug" -eq 1 ]; then
        npm install
    else
        npm install --silent > /dev/null 2>&1
    fi

    echo "Checking for outdated NPM packages..."
    npm outdated --json > npm-outdated.json
    calculateOutdatedness "npm-outdated.json" "npm"

    # Rimuovi il file
    rm -f npm-outdated.json
fi

# count total packages by scoring packages
totalPackages=${#scoringPackages[@]}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

color=$GREEN
# if total score is greater than 1000, change color to yellow, if is greater than 2000, change color to red
if [ "$totalScore" -gt 1000 ]; then
    color=$YELLOW
fi
if [ "$totalScore" -gt 2000 ]; then
    color=$RED
fi

echo -e "${BOLD}${color}**********************************${RESET}"
echo -e "${BOLD}${color}       Outdated Index: $totalScore   ${RESET}"
echo -e "${BOLD}${color}**********************************${RESET}"
echo "Total packages: $totalPackages"
echo "Scoring packages:"
for package in "${scoringPackages[@]}"; do
    echo "$package"
done
