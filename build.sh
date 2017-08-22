#!/bin/bash

while getopts "a:c:" opt; do
  case $opt in
    a)
	ARCH=$OPTARG ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [[ -z "${ARCH}" ]] ; then
	echo 'You need to input arch with -a ARCH.'
	echo 'Supported archs are:'
	echo -e '\tarm arm64 mips mips64 x86 x86_64'
	exit 1
fi

LOCAL_PATH=$(readlink -f .)
NDK_PATH=$(dirname "$(which ndk-build)")

if [ -z ${NDK_PATH} ] || [ ! -d ${NDK_PATH} ] || [ ${NDK_PATH} == . ]; then
	if [ ! -d android-ndk-r15 ]; then
		echo "downloading android ndk..."
		wget https://dl.google.com/android/repository/android-ndk-r15-linux-x86_64.zip
		unzip android-ndk-r15-linux-x86_64.zip
		rm -f android-ndk-r15-linux-x86_64.zip
	fi
	echo 'using integrated ndk'
	NDK_PATH=$(readlink -f android-ndk-r15)
fi

if [ ! -d libmysofa ]; then
	#git clone https://github.com/hoene/libmysofa.git -b 'v0.6' --single-branch libmysofa
	git clone https://github.com/hoene/libmysofa.git libmysofa.git --bare --depth=1
fi

LIBMYSOFA_BARE_PATH=$(readlink -f libmysofa)
ANDROID_API=14

ARCH_CONFIG_OPT=

case "${ARCH}" in
	'arm')
		ARCH_TRIPLET='arm-linux-androideabi'
		ABI='armeabi-v7a'
		ARCH_CFLAGS='-march=armv7-a -mfpu=neon -mfloat-abi=softfp -mthumb'
		ARCH_LDFLAGS='-march=armv7-a -Wl,--fix-cortex-a8' ;;
	'arm64')
		ARCH_TRIPLET='aarch64-linux-android'
		ABI='arm64-v8a'
		ANDROID_API=21 ;;
        'mips')
		ARCH_TRIPLET='mipsel-linux-android'
		ABI='mips' ;;
        'mips64')
		ARCH_TRIPLET='mips64el-linux-android'
		ABI='mips64'
		ANDROID_API=21 ;;
        'x86')
		ARCH_TRIPLET='i686-linux-android'
		ARCH_CONFIG_OPT='--disable-asm'
		ARCH_CFLAGS='-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32'
		ABI='x86' ;;
        'x86_64')
		ARCH_TRIPLET='x86_64-linux-android'
		ABI='x86_64'
		ARCH_CFLAGS='-march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel'
		ANDROID_API=21 ;;
	*)
		echo "Arch ${ARCH} is not supported."
		exit 1 ;;
esac


CROSS_DIR="$(mktemp -d)"
LIBMYSOFA_DIR="$(mktemp -d)"
git clone "${LIBMYSOFA_BARE_PATH}" "${LIBMYSOFA_DIR}"

"${NDK_PATH}"/build/tools/make_standalone_toolchain.py \
            --arch "${ARCH}" --api ${ANDROID_API} \
            --stl libc++ --unified-headers \
            --install-dir "${CROSS_DIR}" --force

pushd "${LIBMYSOFA_DIR}"

git clean -fdx

CROSS_PREFIX="${CROSS_DIR}/bin/${ARCH_TRIPLET}-"

mkdir -p "${LIBMYSOFA_DIR}/dist-${ABI}/"{lib,include}

cmake	-DCMAKE_SYSTEM_NAME=Android \
	-DCMAKE_SYSTEM_VERSION=${ANDROID_ABI} \
	-DCMAKE_ANDROID_ARCH_ABI=${ABI} \
	-DCMAKE_ANDROID_NDK=${NDK_PATH} \
	-DCMAKE_ANDROID_STL_TYPE=gnustl_static \
	-DCMAKE_BUILD_TYPE=Release \
	.
make -j16 mysofa-static
cp src/libmysofa.a "${LIBMYSOFA_DIR}/dist-${ABI}/lib"
cp src/hrtf/mysofa.h "${LIBMYSOFA_DIR}/dist-${ABI}/include"
popd

rm -Rf "${CROSS_DIR}"
cp -R "${LIBMYSOFA_DIR}/dist-${ABI}"  "${LOCAL_PATH}/"
rm -Rf "${LIBMYSOFA_DIR}"

