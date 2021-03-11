#!/bin/bash
#启动命令行调试
appBundle="com.example.myapp"
localEngineDir="/Users/admin/Documents/engine/src/out/android_debug_unopt"
localEngineSRC="/Users/admin/Documents/engine/src"
pid=$(adb shell pidof $appBundle)
#添加符号表
lldb -o "platform select remote-android" -o "platform connect unix-abstract-connect:///data/data/$appBundle/debug.socket" -o "process attach -p $pid" -o "add-dsym $localEngineDir/libflutter.so"
