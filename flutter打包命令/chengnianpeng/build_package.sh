#!/bin/bash

# 使用
# 在项目根目录执行
# 可传参数 
# 第一参数 android/ios/all(default) (android 只编译Android包 ios 只编译iOS all Android和iOS都编译)
# 第二参数 product/release/releaseV2/test(default)/dev/releaseDev/releaseV2Dev/productDev (product 正式环境 releaseV2 灰度环境 release 集成环境 test 测试环境 dev 测试环境开发模式 releaseDev 集成环境开发模式 releaseV2Dev 灰度环境开发模式 productDev 生产环境开发模式)
# 第三参数 single(default)/flavor (single 只构建默认渠道,并根据第二参数上传对应平台 flavor 构建build.gradle配置好的渠道包,该参数对iOS无效)
# 第四参数 更新描述 (用于上传到公测平台的更新描述)
# 第五参数 false(default)/true (false 不执行拉去子项目 true 执行拉去子项目)
# 第六参数 all(default)/Android/... (all 全部 Android 默认渠道 渠道类型)
# 第七参数 beta_pgyer(default)/beta_firim (beta_pgyer 构建上传蒲公英 beta_firim 构建上传fir)

# ./build_package.sh / ./build_package.sh android product single "1.4.0 正式环境" false Android beta_pgyer
# ./build_package.sh android release flavor "1.4.0 集成环境" true Android beta_pgyer

#读取properties文件中的某个属性 macos
function readPropertyMacos() {
  #获取属性名,并将属性名的"."号替换为"\.",以便于后面在gsed中使用
  propertyName=`echo $1 | gsed 's/\./\\\./g'`
  #获取属性文件路径
  fileName=$2;
  #读取属性文件内容,然后使用gsed命令将前缀的空格去掉,删除注释行,选取匹配属性名的行,并将属性名去掉,最后取结果最后一个
  cat $fileName | gsed -n -e "s/^[ ]*//g;/^#/d;s/^$propertyName=//p" | tail -1
}

#读取properties文件中的某个属性 linux
function readPropertyLinux() {
  #获取属性名,并将属性名的"."号替换为"\.",以便于后面在sed中使用
  propertyName=`echo $1 | sed 's/\./\\\./g'`
  #获取属性文件路径
  fileName=$2;
  #读取属性文件内容,然后使用sed命令将前缀的空格去掉,删除注释行,选取匹配属性名的行,并将属性名去掉,最后取结果最后一个
  cat $fileName | sed -n -e "s/^[ ]*//g;/^#/d;s/^$propertyName=//p" | tail -1
}

# 第一个参数为需要mv的路径前缀,第二个参数为文件名
function changeName() {
  echo "changeName 第一参数 $1 第二参数 $2"
  new="$1_$2"
  mv $2 $new
}

# 第一个参数为需要遍历的路径,第二个参数为需要mv的路径前缀
function travFolder() { 
  echo "travFolder 第一参数 $1 第二参数 $2"
  echo "开始遍历文件路径..."
  flist=`ls $1`
  cd $1
  echo "文件路径"
  echo "$flist"
  for f in $flist
  do
    if test -d $f
    then
      echo "继续遍历文件路径"
      echo "$f"
      travFolder "$1$f/" $2
    else
      echo "开始处理文件 $f ..."
      changeName $2 $f
      echo "处理文件 $f 完成"
    fi
  done
  cd ../ 
  echo "遍历文件路径完成"
}

# git clone 指定仓库
# expect 命令结束语
# expect eof
# interact
function expectGit() {
  expect -c "
  set timeout -1
  spawn $1   
  expect {
  "*Username*:" {send $2\r; exp_continue} 
  "*Password*:" {send $3\r}               
  }
  expect eof
  "
}

echo "开始构建版本..."

gitlab_account=''
gitlab_password=''
tencent_git_account=''
tencent_git_password=''
gitee_account=''
gitee_password=''
webview_flutter_repository=''
youxuan_im_plugin_repository=''
flutter_weeget_lib_repository=''
qiyu_flutter_repository=''
flutter_swiper_repository=''

youxuan_im_branch='v1.8.0'


apk_name='优选店主'
version_name='1.0.0'
buildInstallType='1' # 1 免密下载 2 密码下载(需要传 buildPassword)
buildPassword='000000'
api_key='8'
user_key=''
fir_api_key=''
upload_url='https://www.pgyer.com/apiv2/app/upload'
lane_name='beta_pgyer' # beta_pgyer 构建上传蒲公英 beta_firim 构建上传fir
build_type='all'
buildUpdateDescription=''
flutterBuildOutPath='build/app/outputs/flutter-apk/'
projectOutput='output/all/'
build_flavor_type='single' # flavor 打 build.gradle 配置的所有渠道包 single 打默认渠道包 根据 lane_name 的值 上传蒲公英 / fir
env_type='default'
main_file='lib/main.dart'
is_clone_git='false'
flavor_type='all'

function getVersionName() {
  # 根据配置赋值版本号 version_name
  if [ -f "android/local.properties" ]; then

    if [ "$(uname)" == "Darwin" ]; then
      # Mac OS X 操作系统

      if !(command -v gsed > /dev/null 2>&1); then
        echo "gsed command not exists"
        return 0
      fi

      version_name=`readPropertyMacos "flutter.versionName" "android/local.properties"`

    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
      # GNU/Linux操作系统

      if !(command -v sed > /dev/null 2>&1); then
        echo "sed command not exists"
        return 0
      fi

      version_name=`readPropertyLinux "flutter.versionName" "android/local.properties"`

    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
      # Windows NT操作系统
      echo "暂时不能在 Windows 上执行"
      return 0
    fi

    echo "flutter.versionName is $version_name."
  else
    echo "android/local.properties not exists"
    return 0
  fi

}

if [ -n "$1" ]; then
  build_type=$1
fi

if [ -n "$2" ]; then
  env_type=$2

  if [ $env_type == 'default' ]; then
    main_file='lib/main.dart'
  elif [ $env_type == 'test' ]; then
    main_file='lib/main_test.dart'
  elif [ $env_type == 'dev' ]; then
    main_file='lib/main_dev.dart'
  elif [ $env_type == 'release' ]; then
    main_file='lib/main_release.dart'
  elif [ $env_type == 'releaseV2' ]; then
    main_file='lib/main_release_v2.dart'
  elif [ $env_type == 'product' ]; then
    main_file='lib/main_product.dart'
  elif [ $env_type == 'releaseDev' ]; then
    main_file='lib/main_release_dev.dart'
  elif [ $env_type == 'releaseV2Dev' ]; then
    main_file='lib/main_release_v2_dev.dart'
  elif [ $env_type == 'productDev' ]; then
    main_file='lib/main_product_dev.dart'
  fi
fi

if [ -n "$3" ]; then
  build_flavor_type=$3
fi

if [ -n "$4" ]; then
  buildUpdateDescription=$4
fi

if [ -n "$5" ]; then
  is_clone_git=$5
fi

if [ -n "$6" ]; then
  flavor_type=$6
fi

if [ -n "$7" ]; then
  lane_name=$7
fi


if !(command -v git > /dev/null 2>&1); then
  echo "git 命令不存在"
else
  if [ $is_clone_git == 'false' ]; then
    echo "拉取仓库最新代码..."
    git pull
    echo "拉取仓库最新代码完成"
  fi
fi

if !(command -v flutter > /dev/null 2>&1); then
  echo "flutter 命令不存在"
  echo "无法完成 flutter 构建"
  exit 1
fi

if [ $is_clone_git == 'true' ]; then
  if !(command -v expect > /dev/null 2>&1); then
    echo "expect 命令不存在"
    echo "无法完成 flutter 构建"
    exit 1
  fi

  rm -rf youxuan_im_plugin webview_flutter flutter_weeget_lib qiyu_flutter flutter_swiper

  expectGit "git clone ${youxuan_im_plugin_repository}" "${gitlab_account}" "${gitlab_password}"
  echo "youxuan_im_plugin git clone 完成"
  if [ -d "youxuan_im_plugin" ]; then
    cd youxuan_im_plugin
    git checkout -b "${youxuan_im_branch}" "origin/${youxuan_im_branch}"
    cd ..
  fi

  expectGit "git clone ${webview_flutter_repository}" "${gitlab_account}" "${gitlab_password}"
  echo "webview_flutter git clone 完成"

  expectGit "git clone ${flutter_weeget_lib_repository}" "${gitlab_account}" "${gitlab_password}"
  echo "flutter_weeget_lib git clone 完成"
  
  expectGit "git clone ${qiyu_flutter_repository}" "${gitlab_account}" "${gitlab_password}"
  echo "qiyu_flutter git clone 完成"

  expectGit "git clone ${flutter_swiper_repository}" "${gitlab_account}" "${gitlab_password}"
  echo "flutter_swiper git clone 完成"
fi

if [ -d "output" ]; then
  echo "清理旧版本文件..."
  rm -rf output/android/*
  rm -rf output/ios/*
  rm -rf output/all/*
  echo "清理旧版本文件完成"
fi


echo "开始清除 flutter 构建缓存文件..."
flutter clean
echo "清除 flutter 构建缓存文件完成"


echo "开始构建 flutter 依赖包..."
# if [ $is_clone_git == 'true' ]; then
#   expectGit "flutter pub get" "${gitee_account}" "${gitee_password}"
# else
#   flutter pub get
# fi
flutter pub get
echo "构建 flutter 依赖包完成"


if [ ! -d "output" ]; then
  mkdir output
fi

cd output
if [ ! -d "android" ]; then
  mkdir android
fi

if [ ! -d "ios" ]; then
  mkdir ios
fi

if [ ! -d "all" ]; then
  mkdir all
fi
cd ../


projectRoot=$(pwd)
time=$(date "+%Y-%m-%d_%H%M%S")


if [ $build_type == 'all' -o $build_type == 'android' ]; then
  echo "开始构建 Android 版本..."




  if [ $build_flavor_type == 'flavor' ]; then

    if [ $flavor_type == 'all' ]; then
      flutter build apk -t "$main_file"
    else
      flutter build apk --flavor "$flavor_type" -t "$main_file"
    fi

    getVersionName

    travFolder "$projectRoot/$flutterBuildOutPath" "$projectRoot/output/all/${apk_name}_v${version_name}_env-${env_type}"

    # cd "$projectRoot/$projectOutput"
    # zip -q -r "output_${time}.zip" *

    cd "$projectRoot"

  elif [ $build_flavor_type == 'single' ]; then
    flutter build apk --flavor Android -t "$main_file"

    getVersionName

    echo "开始上传 Android 版本到平台..."
    file_path="build/app/outputs/flutter-apk/app-android-release.apk"

    if [ $lane_name == 'beta_pgyer' ]; then
      curl -i -F "file=@${file_path}" -F "_api_key=${api_key}" -F "buildInstallType=${buildInstallType}" -F "buildPassword=${buildPassword}" -F "buildUpdateDescription=${buildUpdateDescription}" "${upload_url}"
    fi

    if [ $lane_name == 'beta_firim' ]; then
      # fir publish "${file_path}" --open -T "${fir_api_key}"

      # 使用 fir_cli 上传
      cd ios/
      fastlane run fir_cli api_token:"${fir_api_key}" specify_file_path:"../${file_path}"
      cd ..
    fi

    echo "上传 Android 版本到平台完成"

    travFolder "$projectRoot/$flutterBuildOutPath" "$projectRoot/output/all/${apk_name}_v${version_name}_env-${env_type}"

    # cd "$projectRoot/$projectOutput"
    # zip -q -r "output_${time}.zip" *

    cd "$projectRoot"

  fi






  # cd android/
  # if !(command -v ./gradlew > /dev/null 2>&1); then
  #   echo "gradle 环境不存在"
  #   echo "无法完成 android 原生包构建"
  # else

  #   if [ $build_flavor_type == 'flavor' ]; then
  #     ./gradlew clean
  #     ./gradlew assembleRelease

  #     getVersionName

  #     travFolder "$projectRoot/$flutterBuildOutPath" "$projectRoot/output/all/${apk_name}_v${version_name}"

  #     cd "$projectRoot/android/"

  #     ./gradlew clean

  #   elif [ $build_flavor_type == 'single' ]; then
  #     ./gradlew clean
  #     ./gradlew assembleAndroidRelease

  #     getVersionName

  #     echo "开始上传 Android 版本到平台..."
  #     file_path="build/app/outputs/flutter-apk/app-android-release.apk"

  #     if [ $lane_name == 'beta_pgyer' ]; then
  #       curl -i -F "file=@${file_path}" -F "_api_key=${api_key}" -F "buildInstallType=${buildInstallType}" -F "buildPassword=${buildPassword}" "buildUpdateDescription=${buildUpdateDescription}" "${upload_url}"
  #     fi

  #     if [ $lane_name == 'beta_firim' ]; then
  #       # fir publish "${file_path}" --open -T "${fir_api_key}"

  #       # 使用 fir_cli 上传
  #       cd ios/
  #       fastlane run fir_cli api_token:"${fir_api_key}" specify_file_path:"../${file_path}"
  #       cd ..
  #     fi

  #     echo "上传 Android 版本到平台完成"

  #   fi

  # fi
  # cd ../




  echo "构建 Android 版本完成"

fi

if [ $build_type == 'all' -o $build_type == 'ios' ]; then

  echo "开始清理 Pod 缓存数据"
  if [ -d "ios/Pods" ]; then
    rm -rf ios/Pods ios/Podfile.lock
  fi
  echo "清理 Pod 缓存数据完成"

  echo "开始 pod install"
  cd ios/
  pod install
  cd ../
  echo "pod install 完成"

  echo "开始构建 iOS Flutter 产物..."
  flutter build ios -t "$main_file"

  if [ $? -eq 0 ]; then
    echo "构建 iOS Flutter 产物完成"

    if !(command -v fastlane > /dev/null 2>&1); then
      echo "fastlane 命令不存在"
      echo "打包上传 iOS 版本失败"
    else
      echo "开始构建 iOS 版本..."
      cd ios/
      fastlane "${lane_name}" "buildInstallType:${buildInstallType}" "buildPassword:${buildPassword}" "buildUpdateDescription:${buildUpdateDescription}" "pgyer_api_key:${api_key}" "pgyer_user_key:${user_key}" "fir_api_key:${fir_api_key}" "build_flavor_type:${build_flavor_type}"
      cd ..
      echo "构建 iOS 版本完成"

      # 拷贝一份到 output/ios
      cp -rf "$projectRoot/ios/output/" "$projectRoot/output/ios/"

      travFolder "$projectRoot/ios/output/" "$projectRoot/output/all/${apk_name}_v${version_name}_env-${env_type}"

      # cd "$projectRoot/$projectOutput"
      # zip -q -r "output_${time}.zip" *

      cd "$projectRoot"


    fi

  else
    echo "构建 iOS Flutter 产物失败"
  fi

  echo "清理 iOS 构建缓存..."
  if [ -d "ios/output" ]; then
    rm -rf ios/output/
  fi
  echo "清理 iOS 构建缓存完成"
fi


if [ $build_type == 'all' -o $build_type == 'ios' -o $build_type == 'android' ]; then
  cd "$projectRoot/$projectOutput"
  zip -q -r "output_${time}.zip" *

  cd "$projectRoot"
fi


echo "开始清除 flutter 构建缓存文件..."
flutter clean
echo "清除 flutter 构建缓存文件完成"

cd ../
echo "清理文件..."
rm -rf output/android/*
rm -rf output/ios/*
echo "清理文件完成"

echo "构建版本完成"

echo "请到以下链接下载版本包"
if [ $build_type == 'all' -o $build_type == 'ios' ]; then
  echo "iOS 版本"
  if [ $build_flavor_type == 'single' ]; then
    echo "蒲公英: https://www.pgyer.com/nqwh"
  fi
fi

if [ $build_type == 'all' -o $build_type == 'android' ]; then
  echo "Android 版本"
  if [ $build_flavor_type == 'single' ]; then
    echo "蒲公英: https://www.pgyer.com/pMs8"
  elif [ $build_flavor_type == 'flavor' ]; then
    echo "渠道包下载: https://flutter.weeget.cn"
  fi
fi

# if [ $build_type == 'all' -o $build_type == 'ios' ] && [ $build_flavor_type == 'flavor' ]; then
#   # 检测 ios-ipa-server 命令
#   if (command -v ios-ipa-server > /dev/null 2>&1) && (command -v nohup > /dev/null 2>&1); then
#     # 启动 ios-ipa-server 服务, web 安装 ipa
#     nohup ios-ipa-server $projectRoot/output/ios/ &
#   else
#     echo "ios-ipa-server 与 nohup 命令不存在 无法启动 ios-ipa-server 服务"
#   fi
# fi
