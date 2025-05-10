#!/bin/bash -x
echo "使用方式：$0 xxx.spec"
sed -i 's/redhat-rpm-config/magic-rpm-config/g' $1
sed -i 's/ffmpeg-free/ffmpeg/g' $1
sed -i 's/bad-free/bad/g' $1
sed -i 's/ugly-free/ugly/g' $1
./transspec.sh $1
if [ "0$2" -eq "01" ]; then
NDEBUG=1
fi
if [ "0$NDEBUG" -eq "01" ]; then
	rpmbuild -ba --nocheck --rmspec --rmsource --without tests --without testsuite --with ghc_prof --without debuginfo --define 'debug_package %{nil}' $1  2>&1 | tee $1.log
else
	QA_RPATHS=$(( 0x0001|0x0010 )) rpmbuild -ba --nocheck --rmspec --rmsource --without tests --without testsuite --with ghc_prof --define='runselftest 0' --define '_unpackaged_files_terminate_build  0' $1  2>&1 | tee $1.log
fi
