#!/bin/bash

VERSION='openssl-3.4.0'
ANDROID_API=24
export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME

function build_openssl()
{
    arch=$1
    toolchain_prefix=$2
    if [ ! -f $VERSION.tar.gz ]; then
        curl -L -O https://www.openssl.org/source/$VERSION.tar.gz
    fi
    if [ ! -d $VERSION ]; then
        tar -xf $VERSION.tar.gz
    fi
    if [ -z $ANDROID_NDK_HOME ]; then
        echo "missing ANDROID_NDK_HOME"
        exit 1
    fi
    if [ ! -d $arch ]; then
        mkdir $arch
    fi

    if [ "$(uname)" == "Darwin" ]; then
        proc="$(sysctl -n hw.logicalcpu)"
        export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin:$PATH"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        proc="$(nproc)"
        export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
        proc="$(nproc)"
        export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/windows-x86_64/bin:$PATH"
    fi
	export CC="$toolchain_prefix$ANDROID_API-clang"
	export CXX="$toolchain_prefix$ANDROID_API-clang++"
	export CXXFLAGS="-fPIC"
	export CPPFLAGS="-DANDROID -fPIC"
    echo "Building OpenSSL for $arch with $CC"

    pushd $VERSION
    ./Configure --prefix="`pwd`/$arch" android-$arch -Wno-macro-redefined -D__ANDROID_API__=$ANDROID_API \
    && make clean \
    && make -j$proc \
    && make install
    popd
}

build_openssl arm64 aarch64-linux-android
build_openssl arm armv7a-linux-androideabi
build_openssl x86 i686-linux-android
build_openssl x86_64 x86_64-linux-android

mkdir -p openssl/include
cp -r $VERSION/arm64/include/* openssl/include

build_apis="armeabi-v7a arm64-v8a x86 x86_64"
for api in $build_apis
do
    if [ ! -d openssl/lib/$api ]; then
        mkdir -p openssl/lib/$api
    fi
done

cp $VERSION/arm64/lib/*.a openssl/lib/arm64-v8a
cp $VERSION/arm/lib/*.a openssl/lib/armeabi-v7a
cp $VERSION/x86/lib/*.a openssl/lib/x86
cp $VERSION/x86_64/lib/*.a openssl/lib/x86_64
