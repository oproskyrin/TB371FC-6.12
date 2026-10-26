#!/bin/sh
# R171: bluedevil 6.7.4 build, OpenMP given explicitly (FindOpenMP try_compile fails with cmake 4.4).
set -eu
cd /run/bd-build
g=$(gcc -print-file-name=libgomp.so)
omp="-DOpenMP_C_FLAGS=-fopenmp -DOpenMP_CXX_FLAGS=-fopenmp -DOpenMP_C_LIB_NAMES=gomp -DOpenMP_CXX_LIB_NAMES=gomp -DOpenMP_gomp_LIBRARY=$g"
rm -rf b2
cmake -S bluedevil-6.7.4 -B b2 -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF $omp > b2.log 2>&1 || { echo B2_CMAKE_FAILED; grep -B2 -A8 "CMake Error" b2.log | head -40; exit 1; }
nice ninja -C b2 -j8 > b2-build.log 2>&1 || { echo B2_FAILED; tail -20 b2-build.log; exit 1; }
DESTDIR=/run/bd-stage/bluedevil ninja -C b2 install > /dev/null
ninja -C b2 install > /dev/null
tar -C /run/bd-stage -cf /run/bd-stage.tar bluez-qt bluedevil
ls -la /run/bd-stage.tar; find /run/bd-stage -type f | wc -l
echo BUILD_OK
