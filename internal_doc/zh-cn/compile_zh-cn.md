***
编译
====

配置
----

+ 查看已有配置

        make help / make list-defconfigs:
        列出Built-in configs，这些配置存在于目录board/configs下

+ 载入已有配置

        make <product>_defconfig

+ 自定义配置

        make menuconfig

        每一项的说明可在配置界面里查看

+ 保存配置

        make savedefconfig

        注意:
          工程配置路径为board/configs, 保存的名称必须以 _defconfig 结尾
          buildroot配置路径为board/configs/$(RV_BOARD_TYPE)/buildroot_config/configs, 保存的名称必须以 _defconfig 结尾

    **对于子模块buildroot和kernel，同样可以在工程根目录执行make buildroot-menuconfig/make
    buildroot-savedefconfig以及make kernel-menuconfig/make kernel-savedefconfig
    来进行模块里的自定义配置和保存配置**

编译
----

+ 全局编译

        make

+ 清除全局编译

        make clean / make distclean

+ 模块编译

        make <module_name>

        <module_name>和rvmk的名称一致

+ 清除模块编译

        make <module_name>-buildclean

+ 模块重新编译

        make <module_name>-rebuild
        相当于 make <module_name>-buildclean && make <module_name>

    **编译时加入V=1可查看编译过程，方便调试**

    **更多，见*`make help`***

    内部生成文档 :

    + 增加新的md，并依据语言类型加入到[`Developer_Guides.md`](../internal_doc/Developer_Guides.md)
      或 [`开发指南.md`](../internal_doc/开发指南.md)
    + `make doc`
    + 用浏览器打开[`doc`](./)目录下的对应html查看

### 特殊模块

+ buildroot

    **TODO...**

生成固件
-------

    make fw

*make fw*:

+ make [pack-kernel](../platform/build/pack-kernel.mk)

+ make [pack-rootfs][rootfs_mk_file]

    - \<buildroot\>/output/target
    - out/target
    - board/\<board_type\>/init.d
    - mksquashfs/gzip

    由于为了固件的尽量小，文件是否被打包进固件是代码显示指定的，
    在增减模块的时候，注意修改[rootfs_mk_file]

[rootfs_mk_file]: ../platform/build/pack-rootfs.mk "roofs makefile"

+ make [partition_setting_ini](../platform/build/pack-partition_setting_ini.mk)

    **固件生成于out/images**

烧写固件
-------

板端：

    短路 或者 烧写键；如果已烧写过能启动控制台，执行reboot loader

Ubuntu:

    make dl

Windows:

    TODO

移植新的模块
============

规则类似于[buildroot](https://buildroot.org/downloads/manual/manual.html),
Config.in做配置，[module_name].rvmk做[Makefile](https://www.gnu.org/software/make/manual/make.html)编译具体命令

Config.in
--------

- 入口[`Config.in`](../platform/build/Config.in)
- 模块Config.in编写时，必须有bool变量RV_TARGET_[MODULE_NAME]，
  当为y的时候，执行make命令时才会编译此模块.
  注意同时修改[rootfs_mk_file]来确定此模块需要打包进固件的文件
- 参考 [`app/hello_rv/Config.in`](../app/hello_rv/Config.in)

[module_name].rvmk
----------------

默认, thirdparty/\*/\*.rvmk, platform/\*/\*.rvmk, app/\*/\*.rvmk文件会被自动添加进总Makefile中.

- 关键自定义函数:

    * [MODULE_NAME]_CONFIGURE_CMDS :  
      生成[MODULE_NAME] configure目标(即变量 [MODULE_NAME]_TARGET_CONFIGURE)时将被调用的函数

    * [MODULE_NAME]_BUILD_CMDS :  
      编译[MODULE_NAME] configure目标时调用的函数，在configure cmds之后

    * [MODULE_NAME]_INSTALL_TARGET_CMDS :  
      生成[MODULE_NAME] install目标时被调用的函数，在build cmds之后

    编译模块时原理上是定义以上三个函数，编译的时候依次调用，所有变量的设置都是为此服务

    * [MODULE_NAME]_MAKECLEAN_CMDS :  
      make [MODULE_NAME]-buildclean时被调用，清除模块编译的中间过程内容

- 关键变量:

    * pkgdir :  
      [module_name].rvmk文件所在目录

    * pkgname / PKGNAME :  
      即[module_name] / [MODULE_NAME]

    * [MODULE_NAME]_BUILDDIR :  
      存放此模块编译中间过程内容的文件目录

    * [MODULE_NAME]_PKGDIR :  
      此模块源代码所在目录

- 可能需要重定义的变量 :

    * [MODULE_NAME]_DEPENDENCIES :  
      定义依赖的模块，会先于当前模块配置编译

    * [MODULE_NAME]_TARGET_FILES :  
      定义执行install所依赖的目标，这些目标有更新变化的时候，<project>根目录执行make，
      [MODULE_NAME] install目标

    * [MODULE_NAME]_CONFIGURE_DEP_CONFIGS :  
      定义configure依赖的变量，当这些变量发生变化的时候，
      make会自动再重新调用生成[MODULE_NAME] configure目标
    
    * [MODULE_NAME]_CONFIGURE_DEP_FILES :  
      定义configure依赖的文件，当这些文件发生变化的时候，
      make会自动再重新调用生成[MODULE_NAME] configure目标.  
      一般是比如Makefile, configure, CMakeLists等会影响配置的文件.

    * [MODULE_NAME]_AUTOCONFIGS :  
      定义需要写入到$(AUTOCONF_HDR_DIR)/[MODULE_NAME]_autoconf.h头文件中的变量，
      这些变量**必须以'RV_TARGET_'开头**.
      当全局配置发生变化时，make会自动生成此头文件，以便代码能依据这些变量的变化来做相应的编译.  
      注意，我们这边约定，本模块的只允许代码中include本模块的[MODULE_NAME]_autoconf.h，
      不允许去include其他模块[other_MODULE_NAME]_autoconf.h，
      如果需要使用到其他模块的变量，可将此变量加入到[MODULE_NAME]_AUTOCONFIGS中，这样，
      这个需要的变量会作为宏定义出现在此模块的[MODULE_NAME]_autoconf.h中
      
    参考范例：[`app/hello_rv/hello_rv.rvmk`][hello_rv.rvmk]

[hello_rv.rvmk]: ../app/hello_rv/hello_rv.rvmk

- 预定义模块 :

    * [pkg-autotools.mk](../platform/build/pkg-autotools.mk) :  
      如果是autotools的方式，则在rvmk文件最后调用$(eval $(rv-generic-autotools));  
      参考范例：[`app/hello/hello_autotools.rvmk`](../app/hello/hello_autotools.rvmk)

    * [pkg-makefile.mk](../platform/build/pkg-makefile.mk) :  
      如果是使用makefile编译方式或者./configure+make编译的方式，
      则在rvmk文件最后调用$(eval $(rv-generic-makefile))或$(eval $(rv-generic-configure));  
      参考范例：[`app/hello/hello_makefile.rvmk`](../app/hello/hello_makefile.rvmk),
      [`app/hello/hello_configure_make.rvmk`](../app/hello/hello_configure_make.rvmk)

    * [pkg-cmake.mk](../platform/build/pkg-cmake.mk) :  
      如果是使用[cmake][cmake_help]编译方式，则在rvmk文件最后调用$(eval $(rv-generic-cmake));  
      参考范例：[`app/hello_rv/hello_rv.rvmk`][hello_rv.rvmk]

    * [pkg-cp.mk](../platform/build/pkg-cp.mk) :  
      如果是已经生成好的二进制文件等，则在rvmk文件最后调用$(eval $(rv-generic-cp));  
      参考范例：[`app/hello/hello_cp.rvmk`](../app/hello/hello_cp.rvmk)

    **如果是未知的编译方式，那么推荐先改造为[cmake][cmake_help]编译方式，然后再按上述来编写规则**
    
[cmake_help]: https://cmake.org/cmake/help/v3.8

*内部develop还需要为新模块增加`dl.ini`*

: *`dl.ini` 变量定义参考`kernel/dl.ini`，`buildroot/dl.ini`等*

