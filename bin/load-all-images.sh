#!/bin/bash

if [[ $# -ne 1 ]]
then
    echo "please input the dir for load images"
    exit 1
fi

LOAD_DIR=$1
[[ ! -d ${LOAD_DIR} ]] && {
    echo "${LOAD_DIR} is not a directory, please set an exist dir"
    exit 1
}

images=$(ls ${LOAD_DIR})

for image in ${images}; do
    docker load -i ${LOAD_DIR}/${image}
done

