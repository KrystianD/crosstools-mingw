FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y wget build-essential cmake zlib1g-dev git libboost-all-dev && \
    apt-get upgrade -y && apt-get clean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

ARG BUILD_CORES=4
ENV MAKEFLAGS=-j${BUILD_CORES}

ARG TARGETS="i686-w64-mingw32 x86_64-w64-mingw32"

WORKDIR /root

ARG BINUTILS_VERSION=2.32

SHELL ["/bin/bash", "-c"]

# binutils
RUN mkdir binutils && cd binutils && \
    wget https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz && \
    tar -xf binutils-${BINUTILS_VERSION}.tar.gz && \
    sed -i 's/install_to_$(INSTALL_DEST) //' binutils-${BINUTILS_VERSION}/libiberty/Makefile.in && \
    sed -i "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/" binutils-${BINUTILS_VERSION}/libiberty/configure && \
    for target in $TARGETS; do \
        (mkdir build-${target} && cd build-${target} && \
         ../binutils-${BINUTILS_VERSION}/configure \
                 --prefix=/usr \
                 --target ${target} \
                 --infodir=/usr/share/info/${target} \
                 --enable-lto --enable-plugins \
                 --enable-deterministic-archives \
                 --disable-multilib --disable-nls \
                 --disable-werror && \
         make -j$(($BUILD_CORES / 2)) && \
         make install) & \
    done && \
    wait -n && wait -n && \
    rm -rf /root/binutils

# mingw-w64-headers
ARG MINGW_VERSION=6.0.0

RUN mkdir headers && cd headers && \
    wget https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW_VERSION}.tar.bz2 && \
    tar -xf mingw-w64-v${MINGW_VERSION}.tar.bz2 && \
    for target in $TARGETS; do \
        (mkdir build-${target} && cd build-${target} && \
         ../mingw-w64-v${MINGW_VERSION}/mingw-w64-headers/configure \
            --prefix=/usr/${target} \
            --enable-sdk=all \
            --enable-secure-api \
            --host=${target} && \
         make -j$(($BUILD_CORES / 2)) && \
         make install) & \
    done && \
    wait -n && wait -n && \
    rm -rf /root/headers

# gcc bootstrap
ARG GCC_VERSION=9.1.0

RUN mkdir gcc-base && cd gcc-base && \
    wget https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz && \
    tar -xf gcc-${GCC_VERSION}.tar.xz && \
    (cd gcc-${GCC_VERSION} && ./contrib/download_prerequisites) && \
    for target in $TARGETS; do \
        (mkdir build-${target} && cd build-${target} && \
         ../gcc-${GCC_VERSION}/configure --prefix=/usr/ \
            --target=${target} \
            --enable-languages=c,lto \
            --enable-static \
            --with-system-zlib \
            --enable-lto --disable-dw2-exceptions \
            --disable-nls --enable-version-specific-runtime-libs \
            --disable-multilib --enable-checking=release && \
         make -j$(($BUILD_CORES / 2)) all-gcc && \
         make install-gcc) & \
    done && \
    wait -n && wait -n && \
    rm -rf /root/gcc-base

# mingw-w64-crt
RUN mkdir crt && cd crt && \
    wget https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW_VERSION}.tar.bz2 && \
    tar -xf mingw-w64-v${MINGW_VERSION}.tar.bz2 && \
    for target in $TARGETS; do \
        (mkdir build-${target} && cd build-${target} && \
         if [ ${target} == "i686-w64-mingw32" ]; then \
             _crt_configure_args="--disable-lib64 --enable-lib32"; \
         elif [ ${target} == "x86_64-w64-mingw32" ]; then \
             _crt_configure_args="--disable-lib32 --enable-lib64"; \
         fi; \
         ../mingw-w64-v${MINGW_VERSION}/mingw-w64-crt/configure \
            --host=${target} \
            --prefix=/usr/${target} \
            --enable-wildcard \
            ${_crt_configure_args} && \
         make -j$(($BUILD_CORES / 2)) && \
         make install) & \
    done && \
    wait -n && wait -n && \
    rm -rf /root/crt

# winpthreads
RUN mkdir winpthreads && cd winpthreads && \
    wget https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW_VERSION}.tar.bz2 && \
    tar -xf mingw-w64-v${MINGW_VERSION}.tar.bz2 && \
    for target in $TARGETS; do \
        (mkdir build-${target} && cd build-${target} && \
         ../mingw-w64-v${MINGW_VERSION}/mingw-w64-libraries/winpthreads/configure \
            --host=${target} \
            --prefix=/usr/${target} \
            --enable-static --enable-shared && \
         make -j$(($BUILD_CORES / 2)) && \
         make install) & \
    done && \
    wait -n && wait -n && \
    rm -rf /root/winpthreads

# gcc
RUN mkdir gcc && cd gcc && \
    wget https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz && \
    tar -xf gcc-${GCC_VERSION}.tar.xz && \
    (cd gcc-${GCC_VERSION} && ./contrib/download_prerequisites) && \
    for target in $TARGETS; do \
        (mkdir build-${target} && cd build-${target} && \
         ../gcc-${GCC_VERSION}/configure --prefix=/usr/ \
            --target=${target} \
            --enable-languages=c,c++,lto \
            --enable-shared --enable-static \
            --enable-threads=posix --enable-fully-dynamic-string \
            --enable-libstdcxx-time=yes --enable-libstdcxx-filesystem-ts=yes \
            --with-system-zlib --enable-cloog-backend=isl \
            --enable-lto --disable-dw2-exceptions --enable-libgomp \
            --disable-multilib --enable-checking=release && \
         make -j$(($BUILD_CORES / 2)) && \
         make install) & \
    done && \
    wait -n && wait -n && \
    rm -rf /root/gcc

# cmake
ARG CMAKE_VERSION=3.14.5

RUN mkdir cmake && cd cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./bootstrap -- -DCMAKE_BUILD_TYPE:STRING=Release && \
    make && \
    make install && \
    rm -rf /root/cmake

# peldd
RUN mkdir peldd && cd peldd && \
    git clone --recursive https://github.com/gsauthof/pe-util.git . && \
    cmake . && \
    make install && \
    rm -rf /root/peldd

# openssl
ARG OPENSSL_VERSION=1.0.2

COPY build_openssl_* /
RUN mkdir openssl && cd openssl && \
    for target in $TARGETS; do \
        (git clone https://github.com/openssl/openssl --depth 1 --branch OpenSSL_${OPENSSL_VERSION//./_}-stable openssl-${target} && \
         cd openssl-${target}/ && \
         target=${target} bash -e /build_openssl_${OPENSSL_VERSION//./_}.sh) & \
    done && \
    wait -n && wait -n && \
    rm -rf /root/openssl

ENV MAKEFLAGS=""
