#!/bin/sh
echo -e "\e[32mValiddating Image\e[0m"

echo NODE_VERSION: ${NODE_VERSION}
echo BACKGROUND_COLOR: ${BACKGROUND_COLOR}

if [ ""$(echo $BACKGROUND_COLOR | tr '[:lower:]' '[:upper:]') = 'RED' ]; then
    echo -e "\e[31mERROR: Invalid Color:\e[0m" ${BACKGROUND_COLOR}
    EXIT_CODE=1
else
  echo -e "\e[32mValidation Complete - No Known Errors\e[0m"
fi

exit ${EXIT_CODE}
