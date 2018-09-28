#!/bin/bash

# WARNING - SCRIPT STILL IN TESTING - USE AT OWN RISK
# WARNING - SCRIPT STILL IN TESTING - USE AT OWN RISK
# WARNING - SCRIPT STILL IN TESTING - USE AT OWN RISK
# WARNING - SCRIPT STILL IN TESTING - USE AT OWN RISK
echo "WARNING - SCRIPT STILL IN TESTING - USE AT OWN RISK"
echo "WARNING - SCRIPT STILL IN TESTING - USE AT OWN RISK"
echo "WARNING - SCRIPT STILL IN TESTING - USE AT OWN RISK"
echo "WARNING - SCRIPT STILL IN TESTING - USE AT OWN RISK"

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
prompt_confirm "Continue? (exit and ask in Discord if unsure)" || exit 0
