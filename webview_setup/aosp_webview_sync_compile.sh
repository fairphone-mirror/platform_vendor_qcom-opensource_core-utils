#Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
#SPDX-License-Identifier: BSD-3-Clause-Clear


#!/bin/bash -e
#Remove -e option from above if you want script to proceed further after an ERROR

#==================== Defines =========================#
DEPOT_TOOLS_URL="https://chromium.googlesource.com/chromium/tools/depot_tools.git"
WEBVIEW_WORKSPACE="webview_chromium"
WEBVIEW_BUILD_OPTIONS_FILE="webview_build_options.txt"
BUILD_OUT_DIR="android_def"
VALIDATED_WEBVIEW_VERSION="137.0.7151.72"
LTO_OPT_PATCHED_WEBVIEW_VERSION="138.0.7184.0"


#==================== Color codes =========================#
IMP="\e[1;31m" #important message
GEN="\e[32m"   #general message
URL="\e[4m"    #url text
END="\e[0m"    #reset to normal at end

echo -e "${IMP}Refer details on AOSP Webview @${URL}https://chromium.googlesource.com/chromium/src/+/lkgr/android_webview/docs/aosp-system-integration.md${END}"
echo -e "${IMP}Execute this script in a new folder on Ubuntu 22.x or above platform by passing Webview version as first parameter like ./<script> ddd.d.ddd.ddd (validated on version ${VALIDATED_WEBVIEW_VERSION})${END}"

if [ $# -eq 0 ]
  then
    echo -e "${IMP}ERROR: Webview version ddd.d.ddd.ddd not passed as first parameter${END}"
    exit
fi

echo -e "${IMP}Make sure that HOME directory has enough storage space${END}"
echo -e "${IMP}It is expected that git, python3 and python packages are installed else install missing pacakges via 'sudo apt install <apt-pacakges>' and 'python3 -m pip install <python3-packages>'${END}"

echo -e "${GEN}Cleaning existing workspace${END}"
rm -rf depot_tools $WEBVIEW_WORKSPACE 


echo -e "${GEN}Installing depot_tools ...${END}"
git clone $DEPOT_TOOLS_URL


echo -e "${GEN}Adding depot_tools to the end of PATH variable${END}"
export PATH="$PATH:$(pwd)/depot_tools"

echo -e "${GEN}Syncing chromium code for compiling webview (may take few hours) ...${END}"
mkdir $WEBVIEW_WORKSPACE
cd $WEBVIEW_WORKSPACE
fetch --nohooks android

echo -e "${GEN}Switching to webview version $1${END}"
cd src
git checkout tags/$1

echo -e "${GEN}Modiyfing .gclient file to sync Profile Guided files for optimized compilation${END}"
sed -i -e 's/"custom_vars": {}/"custom_vars": {"checkout_pgo_profiles": True,}/' ../.gclient

echo -e "${GEN}Installing additional build dependencies and would require sudo password via prompt ...${END}"
./build/install-build-deps.sh --android

echo -e "${GEN}Sync all other projects as per webview version $1 ...${END}"
gclient sync -D --reset


echo -e "${GEN}Applying optimization patches${END}"
ver_to_int() {
    IFS='.' read -r major minor build patch <<< $1
    echo "$(( major * 1000000000000 + minor * 100000000 + build * 10000 + patch ))"
}

if (( $(ver_to_int $1) < $(ver_to_int $LTO_OPT_PATCHED_WEBVIEW_VERSION) ))
  then
    git apply ../../*.patch
fi

echo -e "${IMP}Using build options from file $WEBVIEW_BUILD_OPTIONS_FILE. For recommended webview build options,${END}"
echo -e "${IMP}Please refer @${URL}https://chromium.googlesource.com/chromium/src/+/HEAD/android_webview/docs/aosp-system-integration.md#Choosing-build-options${END}"
mkdir -p out/$BUILD_OUT_DIR
cat ../../$WEBVIEW_BUILD_OPTIONS_FILE > out/$BUILD_OUT_DIR/args.gn
echo "is_high_end_android = true" >> out/$BUILD_OUT_DIR/args.gn


echo -e "${GEN}Generating Ninja Build files ...${END}"
gn gen out/$BUILD_OUT_DIR


echo -e "${GEN}Compiling webview (may take few hours) ...${END}"
autoninja -C out/$BUILD_OUT_DIR system_webview_apk

echo -e "${IMP}IMPORTANT!!! By default the webview apk gets signed with an insecure test key. For distribution to users, it should be signed with a private key,${END}"
echo -e "${IMP}Please refer @${URL}https://chromium.googlesource.com/chromium/src/+/HEAD/android_webview/docs/aosp-system-integration.md#signing-your-webview for more info${END}"

