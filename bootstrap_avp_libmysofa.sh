#!bin/bash

for ARCH in arm x86; do
	if [ ${ARCH} == arm ] ; then
		ABI=armeabi-v7a
	else
		ABI=x86
	fi
	if [[ ! -d dist-${ABI} ]]; then
		( . build.sh -a ${ARCH} )
	fi
done
