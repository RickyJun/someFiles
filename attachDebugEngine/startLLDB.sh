#!/bin/bash

appBundle="com.example.myapp"
localEngineDir="/Users/admin/Documents/engine/src/out/android_debug_unopt"
localEngineSRC="/Users/admin/Documents/engine/src"
pid=$(adb shell pidof $appBundle)
#vscode的launch配置
vscode_config='
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "remote_lldb",
            "type": "lldb",
            "request": "attach",
            "pid": "'$pid'",
            "initCommands": [
                "platform select remote-android",
                "platform connect unix-abstract-connect:///data/data/'$appBundle'/debug.socket"
            ],
            "preRunCommands": [
                "settings append target.exec-search-paths '$localEngineDir'"
            ],
            "postRunCommands": [
                "settings set target.source-map '$localEngineSRC' '$localEngineSRC'"
            ],
        }
    ]
}'
echo $vscode_config
#1通过adb push到设备上
adb push /Users/admin/Library/Android/sdk/ndk/22.0.7026061/toolchains/llvm/prebuilt/darwin-x86_64/lib64/clang/11.0.5/lib/linux/arm/lldb-server  /data/local/tmp/lldb-server
#2通过run-as提升权限，将该文件拷贝到app私有目录。
adb shell run-as $appBundle cp -F /data/local/tmp/lldb-server /data/data/$appBundle/lldb-server
#3然后对该文件增加可执行权限
adb shell run-as $appBundle chmod a+x /data/data/$appBundle/lldb-server
#4在正式启动lldb-server服务前，你需要将之前启动的进程杀掉
adb shell run-as $appBundle killall lldb-server
#5启动lldb-server服务了
adb shell "run-as $appBundle sh -c '/data/data/$appBundle/lldb-server platform --server --listen unix-abstract:///data/data/$appBundle/debug.socket'"
