#!/bin/bash

prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input"
    esac 
  done  
}
curl https://bootstrap.0x03.services/komodo/KMD-bootstrap.tar.gz -o ~/.komodo/KMD-bootstrap.tar.gz

cd /home/$USER/komodo
git remote -v
prompt_confirm "Using correct repo? (exit and ask in Discord if unsure)" || exit 0
git pull
make
