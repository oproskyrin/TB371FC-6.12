#!/bin/sh
# R171 (on the tablet, RAM only): build bluez-qt 6.28.0 + bluedevil 6.7.4 matching the installed
# KF 6.28 / Plasma 6.7.4 / Qt 6.11 (the repo has 6.31/6.8.1 built against Qt 6.12). Results go to
# /run/bd-stage/{bluez-qt,bluedevil} (DESTDIR) and /run/bd-stage.tar.
set -eu
mount -o remount,size=3G /run/r129/rw
pacman -S --needed --noconfirm base-devel cmake ninja extra-cmake-modules wget 2>&1 | grep -E "error|installing" | tail -3 || true
command -v gcc cmake ninja
w=/run/bd-build; rm -rf $w /run/bd-stage; mkdir -p $w /run/bd-stage; cd $w
wget -q https://download.kde.org/stable/frameworks/6.28/bluez-qt-6.28.0.tar.xz
wget -q https://download.kde.org/stable/plasma/6.7.4/bluedevil-6.7.4.tar.xz
ls -la *.tar.xz
for t in bluez-qt-6.28.0 bluedevil-6.7.4; do tar -xf $t.tar.xz; done
cmake -S bluez-qt-6.28.0 -B b1 -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DBUILD_QCH=OFF > b1.log 2>&1 || { tail -20 b1.log; exit 1; }
nice ninja -C b1 -j8 > b1-build.log 2>&1 || { tail -20 b1-build.log; exit 1; }
DESTDIR=/run/bd-stage/bluez-qt ninja -C b1 install > /dev/null
# build bluedevil against the freshly built bluez-qt (install it into / for the build, RAM only)
ninja -C b1 install > /dev/null
cmake -S bluedevil-6.7.4 -B b2 -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF > b2.log 2>&1 || { tail -25 b2.log; exit 1; }
nice ninja -C b2 -j8 > b2-build.log 2>&1 || { tail -20 b2-build.log; exit 1; }
DESTDIR=/run/bd-stage/bluedevil ninja -C b2 install > /dev/null
ninja -C b2 install > /dev/null
tar -C /run/bd-stage -cf /run/bd-stage.tar bluez-qt bluedevil
ls -la /run/bd-stage.tar; find /run/bd-stage -type f | wc -l
echo BUILD_OK
