#!/bin/bash
set -e
docker build -t krystiand/mingw:binutils2.37-mingw9.0.0-gcc10.3.0 -f Dockerfile .
