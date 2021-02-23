#!/bin/bash
#工具版本ruby2.7.1，fastlane2.175.0,注意更新Gemfile,GemFile.lock,Pluginfile,fastlane init 命令重新生成Gemfile,Gemfile.lock，fastlane add_plugin pgyer
#使用gem install fastlane -NV更新最新版
source ~/.bash_profile
#================================子项目仓库
git checkout ${branch}
rvm use 2.7.1
project_path=$(pwd)
flutter_swiper="$project_path/flutter_swiper"
flutter_swiper_path='https://git.code.tencent.com/WG-zhangfeng/flutter_swiper.git'

webview_flutter="$project_path/webview_flutter"
webview_flutter_path="https://gitee.com/weeget_1_wenwenjun/webview_flutter.git"
flutter_weeget_lib="$project_path/flutter_weeget_lib"
flutter_weeget_lib_path="https://git.code.tencent.com/qianyu-app/flutter_weeget_lib.git"
youxuan_im_plugin="$project_path/youxuan_im_plugin"
youxuan_im_plugin_path="https://git.code.tencent.com/qianyu-app/youxuan_im_plugin.git"
youxuan_im_ref=${youxuan_im_ref}
#flutter clean
#==================================拉取子项目

cd $project_path
isClone=${isClone}
if $isClone
then
    echo '=====fetch sub project: flutter_swiper....====='
    echo 'fetching flutter_swiper'
    if [ ! -d $flutter_swiper ];
    then
        git clone $flutter_swiper_path
    fi
    git fetch -f -n $flutter_swiper_path
    echo 'fetching webview_flutter'
    if [ ! -d $webview_flutter ];
    then
        echo 'clone webview_flutter'
        git clone $webview_flutter_path
    fi
    git fetch -f -n $webview_flutter_path
    echo 'fetching flutter_weeget_lib'
    if [ ! -d $flutter_weeget_lib ];
    then
        git clone $flutter_weeget_lib_path
    fi
    git fetch -f -n $flutter_weeget_lib_path $youxuan_im_ref
    echo 'fetching youxuan_im_plugin'
    if [ ! -d $youxuan_im_plugin ];
    then
        git clone $youxuan_im_plugin_path
    fi
    git fetch -f -n $youxuan_im_plugin_path $youxuan_im_ref
fi
flutter pub get
env=${env}
if [ $env == "dev" ]
then
    cp lib/main_dev.dart lib/main.dart
fi
if [ $env=="test" ]
then
    cp lib/main_test.dart lib/main.dart
fi
platform=${platform}
pgyer_api_key=3f8817b66301d9756829ed5bd8896e5b
pgyer_user_key=166b0630f11be5d1a25dcb58d5260dc9
buildUpdateDescription=${buildUpdateDescription}
build_flavor_type=${build_flavor_type}
if [ platform == "ios" ]
then
    #=================================================证书
    security set-key-partition-list -S apple-tool:,apple: -s -k "123456" ~/Library/Keychains/login.keychain-db
    #假设脚本放置在与项目相同的路径下
    
    cd ios
    pod install
    cd ..
    flutter build ios
    cd ios
    export FASTLANE_USER=wenwenjun@weeget.cn
    export APP_IDENTIFIER=cn.weeget.youxuan
    export SCHEME_NAME=Runner
    export FASTLANE_PASSWORD=344939Wen
    
    fastlane beta_pgyer buildUpdateDescription:$buildUpdateDescription pgyer_api_key:$pgyer_api_key pgyer_user_key:$pgyer_user_key build_flavor_type:$build_flavor_type
else
    if build_flavor_type="single"
        apkPath="$project_path/build/app/output/apk/app_android_profile_v1.8.0.apk"
    then
        apkPath="$project_path/build/app/output/apk/${flavor}/app_${flavor}_profile_${youxuan_im_ref}.apk"
    fi
    flutter build apk --flavor ${flavor}
    curl -F "file=@${apkPath}" -F "_api_key=${pgyer_api_key}" -F "buildUpdateDescription=${buildUpdateDescription}" https://www.pgyer.com/apiv2/app/upload -v
fi
