#!/bin/bash
set -e
docker build -t krystiand/mingw:krystiand/mingw:binutils2.32-mingw6.0.0-gcc9.1.0 -f Dockerfile .
