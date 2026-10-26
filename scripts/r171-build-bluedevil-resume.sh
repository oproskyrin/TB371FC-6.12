#!/bin/sh
# R171: continue the bluez-qt/bluedevil build on the tablet independent of the SSH session.
set -eu
cd /run/bd-build
while pgrep -x ninja >/dev/null; do sleep 5; done
ninja -C b1 -j8 > b1-build2.log 2>&1 || { echo B1_FAILED; tail -20 b1-build2.log; exit 1; }
rm -rf /run/bd-stage; mkdir -p /run/bd-stage
DESTDIR=/run/bd-stage/bluez-qt ninja -C b1 install > /dev/null
ninja -C b1 install > /dev/null
cmake -S bluedevil-6.7.4 -B b2 -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF > b2.log 2>&1 || { echo B2_CMAKE_FAILED; tail -25 b2.log; exit 1; }
nice ninja -C b2 -j8 > b2-build.log 2>&1 || { echo B2_FAILED; tail -20 b2-build.log; exit 1; }
DESTDIR=/run/bd-stage/bluedevil ninja -C b2 install > /dev/null
ninja -C b2 install > /dev/null
tar -C /run/bd-stage -cf /run/bd-stage.tar bluez-qt bluedevil
ls -la /run/bd-stage.tar; find /run/bd-stage -type f | wc -l
echo BUILD_OK
