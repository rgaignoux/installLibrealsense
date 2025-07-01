#!/bin/bash
# Builds the Intel Realsense library librealsense on a Jetson Nano Development Kit
# Copyright (c) 2016-21 Jetsonhacks 
# MIT License

LIBREALSENSE_DIRECTORY=${HOME}/librealsense
INSTALL_DIR=$PWD
NVCC_PATH=/usr/local/cuda/bin/nvcc

USE_CUDA=true
NUM_PROCS=1

echo "Build with CUDA: "$USE_CUDA

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
# e.g. echo "${red}The red tail hawk ${green}loves the green grass${reset}"

echo ""
echo "Please make sure that no RealSense cameras are currently attached"
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""

# Install the dependencies
cd $INSTALL_DIR
sudo ./scripts/installDependencies.sh

cd $HOME
wget https://github.com/IntelRealSense/librealsense/archive/refs/tags/v2.50.0.zip -O librealsense-2.50.0.zip
unzip librealsense-2.50.0.zip
mv librealsense-2.50.0 librealsense
rm librealsense-2.50.0.zip

cd $LIBREALSENSE_DIRECTORY

# Now compile librealsense and install
mkdir build 
cd build
# Build examples, including graphical ones
echo "${green}Configuring Make system${reset}"
# Build with CUDA (default), the CUDA flag is USE_CUDA, ie -DUSE_CUDA=true
export CUDACXX=$NVCC_PATH
export PATH=${PATH}:/usr/local/cuda/bin
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64

/usr/bin/cmake ../ -DBUILD_EXAMPLES=true -DFORCE_LIBUVC=ON -DBUILD_WITH_CUDA="$USE_CUDA" -DCMAKE_BUILD_TYPE=release

# The library will be installed in /usr/local/lib, header files in /usr/local/include
# The demos, tutorials and tests will located in /usr/local/bin.
echo "${green}Building librealsense, headers, tools and demos${reset}"

# If user didn't set # of jobs and we have > 4GB memory then
# set # of jobs to # of cores-1, otherwise 1
if [[ $NUM_PROCS == "" ]] ; then
  TOTAL_MEMORY=$(free | awk '/Mem\:/ { print $2 }')
  if [ $TOTAL_MEMORY -gt 4051048 ] ; then
    NUM_CPU=$(nproc)
    NUM_PROCS=$(($NUM_CPU - 1))
  else
    NUM_PROCS=1
  fi
fi

time make -j$NUM_PROCS
if [ $? -eq 0 ] ; then
  echo "librealsense make successful"
else
  # Try to make again; Sometimes there are issues with the build
  # because of lack of resources or concurrency issues
  echo "librealsense did not build " >&2
  echo "Retrying ... "
  # Single thread this time
  time make 
  if [ $? -eq 0 ] ; then
    echo "librealsense make successful"
  else
    # Try to make again
    echo "librealsense did not successfully build" >&2
    echo "Please fix issues and retry build"
    exit 1
  fi
fi
echo "${green}Installing librealsense, headers, tools and demos${reset}"
sudo make install
  
if  grep -Fxq 'export PYTHONPATH=$PYTHONPATH:/usr/local/lib' ~/.bashrc ; then
    echo "PYTHONPATH already exists in .bashrc file"
else
   echo 'export PYTHONPATH=$PYTHONPATH:/usr/local/lib' >> ~/.bashrc 
   echo "PYTHONPATH added to ~/.bashrc. Pyhon wrapper is now available for importing pyrealsense2"
fi

cd $LIBREALSENSE_DIRECTORY
echo "${green}Applying udev rules${reset}"
# Copy over the udev rules so that camera can be run from user space
sudo cp config/99-realsense-libusb.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && udevadm trigger

echo "${green}Library Installed${reset}"
echo " "
echo " -----------------------------------------"
echo "The library is installed in /usr/local/lib"
echo "The header files are in /usr/local/include"
echo "The demos and tools are located in /usr/local/bin"
echo " "
echo " -----------------------------------------"
echo " "
