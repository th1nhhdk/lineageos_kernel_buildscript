# lineageos_kernel_buildscript

Build LineageOS kernel with KernelSU (or not) without having to download unnecessary AOSP or LineageOS source code.

## Supported devices

- Sony Xperia 1 II (`pdx203`)
- Sony Xperia 5 II (`pdx206`) (untested)

## How to use

Link device configuration file in `./configs/` to `./device_config.sh` before running `build.sh`, for example:

```bash
ln -sf ./configs/pdx206_device_config.sh device_config.sh # we are now building for pdx206
```

```bash
build.sh download_sources
# build.sh kernel_defconfig  # optional: build_kernel will check and run it for you if it can't find .config
# build.sh kernel_menuconfig # optional: basically "make menuconfig"
build.sh build_kernel
build.sh make_anykernel3_zip
```

Or run `build_all.sh` to build for all devices listed in `./configs/`.

## Note for WSL users

please remove `/mnt/?` from your `PATH` because it can and will cause conflicts

```
echo $PATH
# only get parts that don't have /mnt/<something>
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/lib/wsl/lib"
```

## Differences compared to building by the LineageOS way

- none (as far as I know)
