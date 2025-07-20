#!/bin/bash

MINION_INSTALL_DIR=/home/markf/Games/minion
cd $MINION_INSTALL_DIR

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

sdk env install
sdk version

OTHER_JARS=$(ls -1 ${MINION_INSTALL_DIR}/lib | while read j; do 
  echo "${MINION_INSTALL_DIR}/lib/$j:"
done | tr -d '\n' | sed 's/:$//')

java -jar Minion-jfx.jar -cp $OTHER_JARS
