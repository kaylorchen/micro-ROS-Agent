#!/bin/bash
apt-get update
apt-get install -y debhelper devscripts fakeroot ros-humble-fastrtps ros-humble-fastcdr
set -xe
source /opt/ros/humble/setup.bash
rosdep update
export EMAIL=kaylor.chen@qq.com
SOURCE_ROOT=$(pwd)
mkdir ${SOURCE_ROOT}/artifacts 
git config --global --add safe.directory ${SOURCE_ROOT}
VERSION=$(git describe --tags --long).$(git branch --show-current).$(TZ="Asia/Shanghai" date +"%Y%m%d.%H%M%S")
VERSION=$(echo ${VERSION} | tr _ -)
VERSION=$(echo ${VERSION} | sed 's/^[^0-9]*//')
echo "Version is $VERSION"
mkdir -pv packages
cd packages
ln -snf ../micro_ros_agent 03_agent
git clone https://github.com/kaylorchen/micro_ros_msgs.git --depth 1 -b release 00_msg
git clone https://github.com/kaylorchen/Micro-XRCE-DDS-Agent.git --depth 1 -b release 01_dds
ls -1 | while IFS= read -r i || [[ -n "$i" ]]; do
    echo "Processing: $i"
    pushd $i
    dch -b -v ${VERSION} $(git log -n 1 --pretty=format:"%s")
    set +e
    pkg=$(head -n 1 debian/changelog | grep ros-humble | awk '{print $1}')
    if [ "$pkg" ]; then
      source /opt/ros/humble/setup.bash
      echo this is a ros package and name is $pkg
      echo "/etc/ros/dds/service-environment.conf /lib/systemd/system/${pkg}.service.d/00-service-environment.conf" > debian/links
    fi
    set -e
    DEB_BUILD_OPTIONS=parallel=15 fakeroot debian/rules binary
    apt install -y --no-install-recommends ../*.deb
    mv -v ../*.deb ${SOURCE_ROOT}/artifacts
  popd
done
