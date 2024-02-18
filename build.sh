#!/bin/sh
set -e

export workdir=$PWD
. $(dirname "$0")/device_config.sh
export MAKEFLAGS="$(echo $(nproc --all) + 2 | bc) $MAKEFLAGS"

download_extract_and_clean() {
    download_dir=$1
    filename=$2
    download_url=$3
    download_mode=$4
    github_dir=$5

    if [ ! -d $workdir/build/$download_dir ]; then
        mkdir -p $workdir/build/$download_dir
        cd $workdir/build/$download_dir
	        echo "=> Downloading: $filename..."
            wget -q --show-progress -O ./$filename $download_url
            echo "=> Extracting: $filename..."
	        tar -xf ./$filename
	        if [ $download_mode = "github" ]; then
	            if [ -z $github_dir ]; then
		            echo "=> ERROR: github_dir variable is missing!"
		            exit 1
		        else
		            echo "=> Moving: $filename's contents to the correct location..."
		            mv $github_dir/* .
		            rm -r $github_dir
                fi
	        fi
	        echo "=> Cleaning up downloaded: $filename..."
            rm ./$filename
        cd $workdir
    else
        echo "=> Already downloaded: $filename, skipping..."
    fi
}

print_help() {
	echo "Usage: $0 {help|download_sources|kernel_defconfig|kernel_menuconfig|build_kernel|make_anykernel3_zip}"
	exit 1
}

add_kernelsu() {
    if [ ! -d $workdir/build/$kernel_name/KernelSU ]; then
        cd $workdir/build/$kernel_name
	    	echo "=> Adding KernelSU to kernel source tree..."
	    	curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
	    cd $workdir
    fi
    cd $workdir/build/$kernel_name
        echo "=> Configuring kprobe which is needed by KernelSU..."
	    sed -i -e '/^CONFIG_KPROBES$/d' \
	    	-e '/^CONFIG_HAVE_KPROBES$/d' \
	    	-e '/^CONFIG_KPROBE_EVENTS$/d' \
	    	./arch/$kernel_arch/configs/"$kernel_defconfig"
        cat >> ./arch/$kernel_arch/configs/"$kernel_defconfig" << EOF
# Required for KernelSU
CONFIG_KPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_KPROBE_EVENTS=y
EOF
        echo "=> Adding -ksu to EXTRAVERSION..."
	    sed -i '/EXTRAVERSION =/c\EXTRAVERSION = -ksu' ./Makefile
    cd $workdir
}

download_sources() {
    [ ! -d $workdir/build ] && mkdir $workdir/build

    [ $need_clang = "true" ] && download_extract_and_clean \
                                "prebuilts/clang/kernel/linux-x86/clang-$clang_version" \
							    "clang-$clang_branch.tar.gz" \
							    "https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-$clang_version/archive/refs/heads/$clang_branch.tar.gz" \
							    "github" \
							    "android_prebuilts_clang_kernel_linux-x86_clang-$clang_version-$clang_branch"

    [ $need_aarch64_gcc = "true" ] && download_extract_and_clean \
                                      "prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-$gcc_version" \
	    							  "aarch64-gcc-$gcc_branch.tar.gz" \
								      "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-$gcc_version/archive/refs/heads/$gcc_branch.tar.gz" \
								      "github" \
								      "android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-$gcc_version-$gcc_branch"

    [ $need_arm_gcc = "true" ] && download_extract_and_clean \
                                  "prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-$gcc_version" \
							      "arm-gcc-$gcc_branch.tar.gz" \
							      "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-$gcc_version/archive/refs/heads/$gcc_branch.tar.gz" \
							      "github" \
							      "android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-$gcc_version-$gcc_branch"

    [ $need_tools_lineage = "true" ] && download_extract_and_clean \
                                        "prebuilts/tools-lineage" \
	    							    "tools-lineage-$lineageos_version.tar.gz" \
								        "https://github.com/LineageOS/android_prebuilts_tools-lineage/archive/refs/heads/$lineageos_version.tar.gz" \
								        "github" \
								        "android_prebuilts_tools-lineage-$lineageos_version"

    [ $need_build_tools = "true" ] && download_extract_and_clean \
                                      "prebuilts/build-tools" \
	    							  "build-tools-$lineageos_version.tar.gz" \
								      "https://github.com/LineageOS/android_prebuilts_build-tools/archive/refs/heads/$lineageos_version.tar.gz" \
								      "github" \
								      "android_prebuilts_build-tools-$lineageos_version"

    [ $need_misc = "true" ] && download_extract_and_clean \
                               "prebuilts/misc" \
	    					   "misc-$aosp_version.tar.gz" \
							   "https://android.googlesource.com/platform/prebuilts/misc/+archive/refs/tags/$aosp_version.tar.gz" \
							   "googlesource"

    [ $need_kernel_build_tools = "true" ] && download_extract_and_clean \
                                             "prebuilts/kernel-build-tools" \
	    					                 "kernel-build-tools-$alt_aosp_version.tar.gz" \
							                 "https://android.googlesource.com/kernel/prebuilts/build-tools/+archive/refs/tags/$alt_aosp_version.tar.gz" \
							                 "googlesource"

    download_kernel

    [ $want_kernelsu = "true" ] && add_kernelsu

    download_anykernel3
}

kernel_defconfig() {
    if [ ! -d $workdir/build/$kernel_name ]; then
        echo "=> ERROR: Cannot find kernel source directory!"
        exit 1
    else
        cd $workdir/build/$kernel_name
            echo "=> Making defconfig configuration file for $device_name"
            [ ! -d ./$kernel_build_out_prefix ] && mkdir ./$kernel_build_out_prefix
	    	eval $path_override \
	        $kernel_make_cmd \
            $kernel_make_flags \
            O="$kernel_build_out_prefix" \
            ARCH="$kernel_arch" \
            CROSS_COMPILE="$kernel_cross_compile" \
            CLANG_TRIPLE="$kernel_clang_triple" \
            CC="$kernel_cc" \
	        "$kernel_defconfig"
        cd $workdir
    fi
}

kernel_menuconfig() {
    if [ ! -d $workdir/build/$kernel_name ]; then
        echo "=> ERROR: Cannot find kernel source directory!"
        exit 1
    else
        cd $workdir/build/$kernel_name
            [ ! -d ./$kernel_build_out_prefix ] && mkdir ./$kernel_build_out_prefix
	    	eval $path_override \
	        $kernel_make_cmd \
            $kernel_make_flags \
            O="$kernel_build_out_prefix" \
            ARCH="$kernel_arch" \
            CROSS_COMPILE="$kernel_cross_compile" \
            CLANG_TRIPLE="$kernel_clang_triple" \
            CC="$kernel_cc" \
	        menuconfig
        cd $workdir
    fi
}

build_kernel() {
    if [ ! -d $workdir/build/$kernel_name ]; then
        echo "=> ERROR: Cannot find kernel source directory!"
        exit 1
    elif [ -f $workdir/build/$kernel_name/$kernel_build_out_prefix/arch/$kernel_arch/boot/Image ]; then
        echo "=> Kernel is already built, skipping..."
    else
        echo "=> Compiling kernel..."
        cd $workdir/build/$kernel_name
            [ ! -d ./$kernel_build_out_prefix ] && kernel_defconfig && cd $workdir/build/$kernel_name
	    	eval $path_override \
	        $kernel_make_cmd \
            $kernel_make_flags \
            O="$kernel_build_out_prefix" \
            ARCH="$kernel_arch" \
            CROSS_COMPILE="$kernel_cross_compile" \
            CLANG_TRIPLE="$kernel_clang_triple" \
            CC="$kernel_cc"
        cd $workdir
    fi
}

make_anykernel3_zip() {
    if [ ! -f $workdir/build/$kernel_name/$kernel_build_out_prefix/arch/$kernel_arch/boot/Image ]; then
        echo "=> ERROR: Kernel image is missing, have you run build.sh build_kernel ?"
        exit 1
    else
        mkdir -p $workdir/out
        cd $workdir/build/AnyKernel3
            echo "=> Creating AnyKernel3 zip at $workdir/$device_name-$kernel_version-$(date +%F)-AnyKernel3.zip..."
            cp $workdir/build/$kernel_name/$kernel_build_out_prefix/arch/$kernel_arch/boot/Image .
            zip -qr9 $workdir/out/$device_name-$kernel_version-$(date +%F)-AnyKernel3.zip * -x .git .gitignore
        cd $workdir
    fi
}

case "$1" in
    help)
        print_help
    ;;
    download_sources)
        download_sources
    ;;
    kernel_defconfig)
        kernel_defconfig
    ;;
    kernel_menuconfig)
	    kernel_menuconfig
    ;;
    build_kernel)
        build_kernel
    ;;
    make_anykernel3_zip)
        make_anykernel3_zip
    ;;
    *)
        print_help
    ;;
esac
