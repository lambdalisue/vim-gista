#!/bin/bash
set -ex
root=$(cd $(dirname $0); pwd)
git config --global user.name "ci"
git config --global user.email ci@example.com
git clone -q --depth 1 --single-branch https://github.com/thinca/vim-themis /tmp/vim-themis
git clone -q --depth 1 --single-branch https://github.com/vim-jp/vital.vim  /tmp/vital
PYTHONUSERBASE=$HOME/.local pip install --user vim-vint
if [ "$VERSION" != "SYSTEM" ]; then
    bash $root/installer/${TRAVIS_OS_NAME}.sh
fi
