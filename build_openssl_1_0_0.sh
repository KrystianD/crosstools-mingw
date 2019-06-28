if [ ${target} == "i686-w64-mingw32" ]; then
	 _args="mingw"
elif [ ${target} == "x86_64-w64-mingw32" ]; then
	 _args="mingw64"
fi
./Configure ${_args} shared enable-ssl2 enable-ssl3 --prefix=/usr/${target}/ --cross-compile-prefix=${target}-
make -j1
make -j1 install_sw
