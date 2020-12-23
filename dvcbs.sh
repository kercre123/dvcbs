#!/bin/bash

set -e

#resources folder. if you put a / at the end it will not work
refo=resources

function help()
{
   echo "-h                                                   This message"
   echo "-dm                                                  Downloads latest OSKR OTA and mounts it in ./oskrlatest directory."
   echo "-m {path/to/ota}                                     Mounts the OTA provided."
   echo "-b {versionbase} {versioncode} {dir}                 Builds apq8009-robot-sysfs.img in directory provided. If you used -dm, don't put a directory. It will auto detect."
   echo "-bt {versionbase} {versioncode} {type} {dir}         Build apq8009-robot-sysfs.img in directory provided with a specific type. Choice are dev, whiskey, oskr. It will auto detect ./oskrcurrent."
   echo "-mbt {versionbase} {versioncode} {type} {dir}        Mounts then builds and OTA with type and dir you provided. Type and dir and required."
   exit 0
}

trap ctrl_c INT                                                                 
                                  
if [ "$EUID" -ne 0 ]
  then echo "Please run this script as root. You can either run 'sudo -s' and then run the script normally, or just run 'sudo ./dvcbs.sh {args}'."
  exit
fi

if [ ! -f ${refo}/ota.pas ]; then
   echo "./${refo}/ota.pas doesn't exist. You may not have the resource folder next to this script, or it is corrupted."
   exit 0
elif [ ! -f ${refo}/build.prop ]; then
   echo "./${refo}/build.prop doesn't exist. You may not have the resources folder next to this script, or it is corrupted."
   exit 0
fi
                                              
function ctrl_c() {
    echo -e "\n\nStopping"
    exit 1 
}

function checktype()
{
if [ ! ${BUILD_TYPE} == "dev" ] || [ ! ${BUILD_TYPE} == "oskr" ] || [ ! ${BUILD_TYPE} == "whiskey" ] || [ ! ${BUILD_TYPE} == "oskrns" ]; then
   if [ -z ${BUILD_TYPE} ]; then
      echo "No build type provided. Using oskr as default."
      BUILD_TYPE=oskr
      BUILD_SUFFIX=oskr
elif [ ${BUILD_TYPE} == "prod" ]; then
      echo "Prod build type selected. This won't be installable on your prod bot. This will just be versioned as a prod image."
      #i dont want to do this right now
      exit 0
   elif [ ${BUILD_TYPE} == "dev" ]; then
      echo "Dev build type selected. Note that this won't work on your OSKR bot. Only Anki-unlocked bots. This build won't be signed."
      BUILD_SUFFIX=d
   elif [ ${BUILD_TYPE} == "oskr" ]; then
      echo "OSKR build type selected."
      BUILD_SUFFIX=oskr
   elif [ ${BUILD_TYPE} == "whiskey" ]; then
      echo "Whiskey build type selected. This will work on a dev bot, but rampost may flash a weird dfu causing the back lights to go weird. This is meant for Whiskey DVT1 bots and not normal bots."
      BUILD_SUFFIX=d
   elif [ ${BUILD_TYPE} == "oskrns" ]; then
      echo "OSKR no signing build type selected. This build won't be signed."
      BUILD_SUFFIX=oskr
else
      echo "Provided build type invalid. Choices: dev, oskr, oskrns, whiskey"
      exit 0
fi
fi
}

function checkforandgenkey()
{
if [ ! -f ${refo}/private.pem ]; then
    echo "Private key not found! Generating one..."
    openssl genrsa -out ${refo}/private.pem 2048
    echo "Generated in ${refo}/private.pem. Now getting public key..."
    openssl rsa -in ${refo}/private.pem -outform PEM -pubout -out ${refo}/public.pub
    echo "Public key now in ${refo}/public.pub! SCP this to /data/etc/ota_keys in your OSKR bot so he can use this OTA!"
    echo "Do NOT share your private.pem! Only share your public.pub!"
fi
}

function parsedirbuild()
{
if [ -z "${origdir}" ]; then
    echo "Directory not provided. Checking ./oskrcurrent"
    if [ -f oskrcurrent/apq8009-robot-sysfs.img ]; then
        echo "./oskrcurrent has a mounted OTA. Using."
        dir=oskrcurrent/
    else 
        echo "Please provide a directory or use "./dvcbs.sh -dm" to download then build the latest OSKR OTA."
        exit 0
    fi
elif [ -f ${origdir}apq8009-robot-sysfs.img ]; then
        echo "apq8009-robot-sysfs.img found."
        dir=${origdir}
elif [ -f ${origdir}/apq8009-robot-sysfs.img ]; then
        echo "apq8009-robot-sysfs.img found."
        dir=${origdir}/
     else
     echo "Please provide a directory with a mounted OTA in it or use -dm to download the latest OSKR build and mount it. If you did use -dm, do not provide a directory."
     exit 0
fi
}

function parsedirmount()
{
if [ -z "${origdir}" ]; then
    dir=oskrcurrent/
elif [ -f ${origdir}* ]; then
        echo "Dir parsed successfully."
        dir=${origdir}
elif [ -f ${origdir}/* ]; then
        echo "Dir parsed successfully."
        dir=${origdir}/
else 
     echo "Please provide a directory with a .ota or apq8009-robot-sysfs.img in it or use -dm to download the latest OSKR build and mount it."
     exit 0
fi
if [ -f ${dir}*.ota ]; then
    echo "OTA is in ./${dir}."
elif [ -d ${dir}edits/anki ]; then
    echo "${dir} already has a mounted OTA."
    exit 0
elif [ -d ${dir}edits ]; then
    echo "${dir}edits exists."
    if [ -f ${dir}apq8009-robot-sysfs.img ]; then
        echo "Mounting apq8009-robot-sysfs.img in ${dir}edits!"
	mount -o loop,rw,sync ${dir}apq8009-robot-sysfs.img ${dir}edits
	echo "Mounted in ${dir}edits!"
	exit 0
    else
	echo "No robot image or OTA to mount. Please provide a directory with a .ota or apq8009-robot-sysfs.img in it or use -dm to download the latest OSKR build and mount it."
        exit 0
    fi
elif [ -f ${dir}apq8009-robot-sysfs.img ]; then
    echo "There is a robot image to mount, but no edits folder. Making directory then mounting."
    mkdir ${dir}edits
    mount -o loop,rw,sync ${dir}apq8009-robot-sysfs.img ${dir}edits
    echo "Mounted in ${dir}edits!"
    exit 0
else
    echo "Nothing to mount. Please provide a directory with a .ota or apq8009-robot-sysfs.img in it or use -dm to download the latest OSKR build and mount it."
    exit 0
fi
}

function precheck()
{
if [ -z ${code} ]; then
   echo "Provide a version base and version code. For example, 1.8.0 123."
   exit 0
fi
}

function downloadmount()
{
if [ ! -d oskrcurrent ]; then
    echo "Making ./oskrcurrent folder."
    mkdir oskrcurrent
fi
if [ ! -f oskrcurrent/* ]; then
    echo "Downloading latest OSKR OTA from DDL servers."
    curl -o oskrcurrent/latest.ota http://ota.global.anki-services.com/vic/oskr/full/latest.ota
    echo "Done downloading."
else if [ -f oskrcurrent/manifest.ini ]; then
    echo "An OTA has already been mounted here. Delete everything in the directory or build."
    exit 0
else if [ -f oskrcurrent/*.ota ]; then
    echo "There is already an OTA in here. Using."
fi
fi
fi
}

function copyfull()
{
  if [ -d ${dir}edits/anki ]; then
	echo "There is a mounted image in here!"
  else if [ -d ${dir}edits ]; then
	echo "The image isn't mounted. Mounting!"
	mount -o loop,rw,sync ${dir}apq8009-robot-sysfs.img ${dir}edits
  else
	echo "It looks like there is an image, but no edits folder. Creating edits folder then continuing."
	mkdir ${dir}edits
	mount -o loop,rw,sync ${dir}apq8009-robot-sysfs.img ${dir}edits
  fi
  fi
  echo "Adding base and code to build.prop"
  cp -rp ${refo}/build.prop ${dir}edits/
  echo ro.anki.product.name=Vector >> ${dir}edits/build.prop
  echo "Setting timestamp"
  echo ro.build.version.release=202012210131 >> ${dir}edits/build.prop
  echo 202012210131 > ${dir}edits/etc/timestamp
  echo ro.product.name=Vector >> ${dir}edits/build.prop
  echo ro.revision=project-victor_os >> ${dir}edits/build.prop
  echo ro.anki.version=${base}.${code} >> ${dir}edits/build.prop
  echo ro.anki.victor.version=${base}.${code} >> ${dir}edits/build.prop
  echo ro.build.fingerprint=${base}.${code}${BUILD_SUFFIX} >> ${dir}edits/build.prop
  echo ro.build.id=${base}.${code}${BUILD_SUFFIX} >> ${dir}edits/build.prop
  echo ro.build.display.id=v${base}.${code}${BUILD_SUFFIX} >> ${dir}edits/build.prop
  echo ro.build.type=development >> ${dir}edits/build.prop
  echo ro.build.version.incremental=${code} >> ${dir}edits/build.prop
  echo ro.build.user=custom >> ${dir}edits/build.prop
  echo ${base}.${code} > ${dir}edits/anki/etc/version
  echo ${base}.${code}${BUILD_SUFFIX} > ${dir}edits/etc/os-version
  echo ${base} > ${dir}edits/etc/os-version-base
  echo ${code} > ${dir}edits/etc/os-version-code
  echo "Putting in correct kernel modules"
  rm -rf ${dir}edits/usr/lib/modules
  cp -r ${refo}/modules/${BUILD_TYPE}/modules ${dir}edits/usr/lib/
  chmod -R +rwx ${dir}edits/usr/lib/modules
  echo "Putting in new update-engine"
  cp ${refo}/update-engines/${BUILD_TYPE} ${dir}edits/anki/bin/update-engine
  chmod +rwx ${dir}edits/anki/bin/update-engine
  if [ ! -f ${dir}edits/anki/bin/vic-log-event ]; then
     echo "This doesn't contain vic-log-event which is required for update-engine to work. Maybe you are messing with older vicos. Copying it in."
     cp ${refo}/vic-log-event ${dir}edits/anki/bin/
     chmod +rwx ${dir}edits/anki/bin/vic-log-event
     echo "Since that wasn't here, this script will put in an emergency update engine in case the normal one doesn't work. This will be called /anki/bin/basic-update-engine."
     if [ ${BUILD_TYPE} == "oskr" ]; then
        echo "This is an oskr build, so signing will be implemented into the basic engine."
        cp ${refo}/update-engines/basic-oskr-update-engine ${dir}edits/anki/bin/basic-update-engine
     else
        echo "This is not an oskr build, so signing will not be implented into the basic update engine."
        cp ${refo}/update-engines/basic-update-engine ${dir}edits/anki/bin/basic-update-engine
     fi
     chmod +rwx ${dir}edits/anki/bin/basic-update-engine
  fi
  if [ ! -f ${dir}edits/anki/etc/update-engine.env ]; then
     echo "No update-engine.env. This anki folder must be really old! Copying one in."
     cp ${refo}/update-engine.env ${dir}edits/anki/etc/
  fi
  if [ -d ${dir}edits/etc/ssh ]; then
     if grep -q "victor" ${dir}edits/etc/ssh/authorized_keys; then
        echo "This build has a global ssh_root_key, and will not accept an oskr bot specific one. You can get the key here: https://wire.my.to/evresources/ssh_root_key"
     fi
  else
     echo "No ssh in this build. Must be prod or rc."
  fi
  echo "Putting in your OTA signing key. Original ota.pub will be left in as a backup as /anki/etc/anki.pub."
  if [ ! -f ${dir}edits/anki/etc/anki.pub ]; then
  mv ${dir}edits/anki/etc/ota.pub ${dir}edits/anki/etc/anki.pub
fi
  cp ${refo}/public.pub ${dir}edits/anki/etc/ota.pub
  if [ -f ${dir}edits/anki/data/assets/cozmo_resources/config/server_config.json ]; then
    if grep -q "dev" ${dir}edits/anki/data/assets/cozmo_resources/config/server_config.json; then
      echo "There is a dev server config in here. Copying in a prod config."
      cp ${refo}/server_config.json ${dir}edits/anki/data/assets/cozmo_resources/config/server_config.json
  fi
fi
  cp ${refo}/boots/${BUILD_TYPE}.img.gz ${refo}/apq8009-robot-boot.img.gz
}

function mountota()
{
  echo "Mounting OTA in $dir!"
  mv ${dir}*.ota ${dir}latest.tar
  tar -xf ${dir}latest.tar --directory ${dir}
  mkdir ${dir}edits
  echo "Decrypting"
  openssl enc -d -aes-256-ctr -pass file:${refo}/ota.pas -md md5 -in ${dir}apq8009-robot-sysfs.img.gz -out ${dir}apq8009-robot-sysfs.img.dec.gz
  echo "Decompressing. This may take a minute."
  gzip -d ${dir}apq8009-robot-sysfs.img.dec.gz
  echo "Rename img.dec to img"
  mv ${dir}apq8009-robot-sysfs.img.dec ${dir}apq8009-robot-sysfs.img
  echo "Mounting IMG"
  mount -o loop,rw,sync ${dir}apq8009-robot-sysfs.img ${dir}edits
  echo "Removing tmp files"
  rm ${dir}apq8009-robot-sysfs.img.gz
  rm -f ${dir}latest.tar
  rm -f ${dir}/manifest.sha256
  rm -f ${dir}apq8009-robot-boot.img.gz
  rm -f ${dir}manifest.ini
  echo "Done! You can now mess around (as root) in ${dir}edits/."
}

function buildcustomandsign()
{
  echo "Compressing. This may take a minute."
  umount ${dir}edits
  gzip -k ${dir}apq8009-robot-sysfs.img
  mkdir ${dir}final
  echo "Encrypting"
  openssl enc -e -aes-256-ctr -pass file:${refo}/ota.pas -md md5 -in ${dir}apq8009-robot-sysfs.img.gz -out ${dir}final/apq8009-robot-sysfs.img.dec.gz
  mkdir ${dir}tempSign
  cp ${dir}final/apq8009-robot-sysfs.img.dec.gz ${dir}tempSign/apq8009-robot-sysfs.img.gz
  echo "Decrypting into temp directory to get correct hash"
  openssl enc -d -aes-256-ctr -pass file:${refo}/ota.pas -md md5 -in ${dir}tempSign/apq8009-robot-sysfs.img.gz -out ${dir}tempSign/apq8009-robot-sysfs.img.dec.gz
  gzip -d ${dir}tempSign/apq8009-robot-sysfs.img.dec.gz
  mv ${dir}final/apq8009-robot-sysfs.img.dec.gz ${dir}/final/apq8009-robot-sysfs.img.gz
  echo "Figuring out SHA256 sum and putting it into manifest."
  sysfssum=$(sha256sum ${dir}tempSign/apq8009-robot-sysfs.img.dec | head -c 64)
  #echoing would be long so just printf
  printf '%s\n' '[META]' 'manifest_version=1.0.0' 'update_version='${base}'.'${code}${BUILD_SUFFIX} 'ankidev=1' 'num_images=2' 'reboot_after_install=0' '[BOOT]' 'encryption=1' 'delta=0' 'compression=gz' 'wbits=31' 'bytes=12869632' 'sha256=91cb7acb9d97bb7d979a91a3f980a75dbad11f002b013faee0383a8fa588fa67' '[SYSTEM]' 'encryption=1' 'delta=0' 'compression=gz' 'wbits=31' 'bytes=608743424' 'sha256='${sysfssum} >${refo}/manifest.ini
  if [ ${BUILD_TYPE} == "oskr" ]; then
     echo "Signing manifest.ini"
     openssl dgst -sha256 -sign ${refo}/private.pem -out ${refo}/manifest.sha256 ${refo}/manifest.ini
  else
     echo "Not signing because build type is not oskr."
  fi
  echo "Putting into tar."
  tar -C ${refo} -cvf ${refo}/temp.tar manifest.ini
  if [ ${BUILD_TYPE} == "oskr" ]; then
     tar -C ${refo} -rf ${refo}/temp.tar manifest.sha256
  else
     echo "Not putting manifest.sha256 in because the build type is not oskr."
  fi
  tar -C ${refo} -rf ${refo}/temp.tar apq8009-robot-boot.img.gz
  cp ${refo}/temp.tar ${dir}final/
  tar -C ${dir}final -rf ${dir}final/temp.tar apq8009-robot-sysfs.img.gz
  mv ${dir}final/temp.tar ${dir}final/${base}.${code}.ota
  echo "Removing some temp files."
  rm -rf ${dir}edits
  rm -f ${dir}final/apq8009-robot-sysfs.img.gz
  rm -f ${dir}apq8009-robot-sysfs.img
  rm -f ${dir}apq8009-robot-sysfs.img.gz
  rm -f ${refo}/manifest.ini
  rm -f ${refo}/manifest.sha256
  rm -f ${refo}/temp.tar
  rm -rf ${dir}tempSign
  rm -r ${refo}/apq8009-robot-boot.img.gz
  mv ${dir}final/${base}.${code}.ota ${dir}
  rm -rf ${dir}final
  echo "Done! Output should be in ${dir}${base}.${code}.ota!"
}
  

if [ $# -gt 0 ]; then
    case "$1" in
	-h)
	    help
            ;;
	-m) 
	    origdir=$2
            parsedirmount
	    mountota
	    ;;
	-dm) 
	    downloadmount
	    dir=oskrcurrent/
	    mountota
	    ;;
	-b) 
	    base=$2
	    code=$3
	    origdir=$4
	    BUILD_TYPE=oskr
	    BUILD_SUFFIX=oskr
	    precheck
      checkforandgenkey
	    parsedirbuild
	    copyfull
	    buildcustomandsign
	    ;;
	-bt)
	    base=$2
	    code=$3
	    BUILD_TYPE=$4
	    origdir=$5
	    checktype
	    precheck
      checkforandgenkey
	    parsedirbuild
	    copyfull
	    buildcustomandsign
	    ;;
  -mbt)
      base=$2
      code=$3
      BUILD_TYPE=$4
      origdir=$5
      parsedirmount
      mountota
      checktype
      precheck
      checkforandgenkey
      parsedirbuild
      copyfull
      buildcustomandsign
      ;;
  -bf)
      base=$2
      code=$3
      origdir=$4
      BUILD_TYPE=oskr
      checktype
      precheck
      checkforandgenkey
      parsedirbuild
      copyfull
      echo OSKR > ${dir}edits/robit
      buildcustomandsign
      if [ ! -d all/oskrfinal ]; then
        mkdir -p all/oskrfinal
      fi
      if [ ! -d all/whiskeyfinal ]; then
        mkdir -p all/whiskeyfinal
      fi
      if [ ! -d all/devfinal ]; then
        mkdir -p all/devfinal
      fi
      if [ ! -d all/oskrnsfinal ]; then
        mkdir -p all/oskrnsfinal
      fi
      rm -rf all/oskrfinal/*
      rm -rf all/whiskeyfinal/*
      rm -rf all/devfinal/*
      rm -rf all/oskrnsfinal/*
      cp ${dir}* all/oskrfinal/
      cp ${dir}* all/whiskeyfinal/
      cp ${dir}* all/devfinal/
      cp ${dir}* all/oskrnsfinal/
      origdir=all/whiskeyfinal/
      BUILD_TYPE=whiskey
      parsedirmount
      mountota
      checktype
      precheck
      checkforandgenkey
      parsedirbuild
      copyfull
      buildcustomandsign
      origdir=all/devfinal/
      BUILD_TYPE=dev
      parsedirmount
      mountota
      checktype
      precheck
      checkforandgenkey
      parsedirbuild
      copyfull
      buildcustomandsign
      origdir=all/oskrnsfinal/
      BUILD_TYPE=oskrns
      parsedirmount
      mountota
      echo OSKRns> ${dir}edits/robit
      checktype
      precheck
      checkforandgenkey
      parsedirbuild
      copyfull
      buildcustomandsign
      echo "All builds are done. ./all"
      ;;
	*)
	    help
	    ;;
    esac
    else
    help
fi
