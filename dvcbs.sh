#!/bin/bash

set -e

#resources folder
refo=resources

function help()
{
   echo "-h                                         This message"
   echo "-dm                                        Downloads latest OSKR OTA and mounts it in ./oskrlatest directory."
   echo "-m {path/to/ota}                           Mounts the OTA provided."
   echo "-b {versionbase} {versioncode} {dir}       Builds apq8009-robot-sysfs.img in directory provided. If you used -dm, don't put a directory. It will auto detect."
   exit 0
}

trap ctrl_c INT                                                                 
                                  
if [ "$EUID" -ne 0 ]
  then echo "Please run this script as root. You can either run '-s' and then run the script normally, or just run 'sudo ./dvcbs.sh {args}'."
  exit
fi

if [ ! -f ${refo}/apq8009-robot-boot.img.gz ]; then
   echo "./${refo}/apq8009-robot-boot.img.gz doesn't exist. You may not have the resources folder next to the script, or it is corrupted."
elif [ ! -f ${refo}/ota.pas ]; then
   echo "./${refo}/ota.pas doesn't exist. You may not have the resource folder next to this script, or it is corrupted."
elif [ ! -f ${refo}/build.prop ]; then
   echo "./${refo}/build.prop doesn't exist. You may not have the resources folder next to this script, or it is corrupted."
fi
                                              
function ctrl_c() {
    echo -e "\n\nStopping"
    exit 1 
}

function checkforandgenkey()
{
if [ ! -f ${refo}/private.pem ]; then
    echo "Private key not found! Generating one for ya..."
    openssl genrsa -out ${refo}/private.pem 2048
    echo "Generated in ${refo}/private.pem. Now getting public key..."
    openssl rsa -in ${refo}/private.pem -outform PEM -pubout -out ${refo}/public.pem
    echo "Public key now in ${refo}/public.pem! SCP this to /data/etc/ota_keys in your OSKR bot so he can use this OTA!"
    echo "Do NOT share your private.pem! Only share your public.pem!"
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
  echo ro.build.version.release=202005190931 >> ${dir}edits/build.prop
  echo ro.product.name=Vector >> ${dir}edits/build.prop
  echo ro.revision=project-victor_os >> ${dir}edits/build.prop
  echo ro.anki.version=${base}.${code} >> ${dir}edits/build.prop
  echo ro.anki.victor.version=${base}.${code} >> ${dir}edits/build.prop
  echo ro.build.fingerprint=${base}.${code}oskr >> ${dir}edits/build.prop
  echo ro.build.id=${base}.${code}oskr >> ${dir}edits/build.prop
  echo ro.build.display.id=${base}.${code}d_os${base}.${code} >> ${dir}edits/build.prop
  echo ro.build.type=development >> ${dir}edits/build.prop
  echo ro.build.version.incremental=${code} >> ${dir}edits/build.prop
  echo ro.build.user=custom >> ${dir}edits/build.prop
  echo ${base}.${code} > ${dir}edits/anki/etc/version
  echo ${base}.${code}oskr > ${dir}edits/etc/os-version
  echo ${base} > ${dir}edits/etc/os-version-base
  echo ${code} > ${dir}edits/etc/os-version-code
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
  printf '%s\n' '[META]' 'manifest_version=1.0.0' 'update_version='${base}'.'${code}'oskr' 'ankidev=1' 'num_images=2' 'reboot_after_install=0' '[BOOT]' 'encryption=1' 'delta=0' 'compression=gz' 'wbits=31' 'bytes=12869632' 'sha256=91cb7acb9d97bb7d979a91a3f980a75dbad11f002b013faee0383a8fa588fa67' '[SYSTEM]' 'encryption=1' 'delta=0' 'compression=gz' 'wbits=31' 'bytes=608743424' 'sha256='${sysfssum} >${refo}/manifest.ini
  echo "Signing manifest.ini"
  openssl dgst -sha256 -sign ${refo}/private.pem -out ${refo}/manifest.sha256 ${refo}/manifest.ini
  echo "Putting into tar."
  tar -C ${refo} -cvf ${refo}/temp.tar manifest.ini
  tar -C ${refo} -rf ${refo}/temp.tar manifest.sha256
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
	    precheck
	    parsedirbuild
	    copyfull
	    checkforandgenkey
	    buildcustomandsign
	    ;;
	*)
	    help
	    ;;
    esac
    else
    help
fi
