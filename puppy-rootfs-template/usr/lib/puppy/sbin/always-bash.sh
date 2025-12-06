#!/bin/bash

if [ "$(readlink /usr/bin/sh 2> /dev/null | xargs -i basename {})" != "bash" ]; then
  rm -f /usr/bin/sh
  ln -sr /usr/bin/bash /usr/bin/sh
fi
