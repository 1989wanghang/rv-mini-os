***
准备
====

编译环境
-------


- ubuntu 14.04:

    `不支持`

- ubuntu 16.04:

        sudo apt install wget git repo build-essential libncurses5-dev minicom

    `RK人员还需要执行(markdown语法遵循`[`pandoc`][pandoc_manual]`):`
    * `sudo apt autoremove pandoc`
    * `sudo apt install happy`
    * `sudo apt install cabal-install`
    * `cabal update`
    * `cabal install pandoc pandoc-include pandoc-citeproc --constraint 'pandoc < 2'`
    * `添加$HOME/.cabal/bin到PATH环境变量中`

[pandoc_manual]: https://pandoc.org/MANUAL.html#pandocs-markdown

- ubuntu 18.04:

    `后续支持`

SDK 工程下载
-----------

### 对外release 版本 ###

+ 下载

    ```
    mkdir <project dir>
    repo init -u ssh://git@10.10.10.78:2222/argus/manifest.git -b master \
    -m rv1108_release.xml --no-repo-verify
    cd <project dir>
    repo sync
    ```

+ 同步/更新

>     cd <project dir> && repo sync

+ 目录结构简要说明

> [`rv1108 目录树`](../README.md)

### 内部develop ###

+ 下载

    ```
    git clone ssh://wangh@10.10.10.29:29418/rk/rk1108/apps/video \
    -o gerrit -b develop <project dir>
    ```

+ 同步/更新

>     cd <project dir> && ./dl.py

