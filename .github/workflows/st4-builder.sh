name: Build OpenWrt

on:
  workflow_dispatch:
    inputs:
      openwrt_version:
        description: 'Pilih Versi OpenWrt'
        required: true
        type: choice
        default: 'master'
        options:
          - master
          - openwrt-24.10
          - openwrt-23.05
          - openwrt-22.03

jobs:
  build:
    runs-on: ubuntu-22.04

    permissions:
      contents: write

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Initialize environment
      env:
        DEBIAN_FRONTEND: noninteractive
      run: |
        sudo -E apt-get -qq update
        sudo -E apt-get -qq install ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev libreadline-dev libssl-dev libtool lrzsz mkisofs msmtp ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pip qemu-utils rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim-common wget xmlto xxd zlib1g-dev
        
    - name: Clone OpenWrt source code
      env:
        REPO_URL: https://github.com/openwrt/openwrt
        REPO_BRANCH: ${{ github.event.inputs.openwrt_version }}
      run: |
        git clone --depth 1 -b $REPO_BRANCH $REPO_URL openwrt
        cd openwrt
        echo "CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)" >> $GITHUB_ENV
        
    - name: Load custom feeds
      run: |
        cd openwrt
        ./scripts/feeds update -a
        ./scripts/feeds install -a

    - name: Load custom configuration
      run: |
        cd openwrt
        rm -f .config
        cp ../.config .config
        make defconfig

    - name: Download package
      run: |
        cd openwrt
        make download -j$(nproc)
        find dl -size -1024c -exec ls -l {} \;
        find dl -size -1024c -exec rm -f {} \;

    - name: Build firmware
      run: |
        cd openwrt
        echo -e "$(nproc) thread build."
        make -j$(nproc) V=s

    - name: Upload firmware
      run: |
        cd openwrt/bin/targets/*/*
        rm -f *emmc* *ext4* *squashfs* *vdi* *vmdk*
        echo "FIRMWARE_PATH=$(pwd)" >> $GITHUB_ENV

    - name: Create release
      uses: softprops/action-gh-release@v2
      with:
        tag_name: openwrt-${{ env.CURRENT_BRANCH }}-${{ github.run_id }}
        files: ${{ env.FIRMWARE_PATH }}/*
