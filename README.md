# dvcbs
DDL Vector Custom Build Script

This script is an update on my previous script. This one is a lot more automated, checks for everything I could think of, and is something I could actually see a regular dev using without that much hassle.

This is a bash script, so you have to run it in a Linux environment.

## Installation
I recommend making a build directory. This can be wherever you want. 

I will just use /home/user/vbuild. Replace user with your user account name.

`mkdir /home/user/vbuild`

`cd /home/user/vbuild`

`git clone https://github.com/kercre123/dvcbs.git`

`chmod +rwx *`

`sudo -s`

`./dvcbs.sh -h`

If you have your own private key to sign the OTA with, place it in ./resources/private.pem

If you don't have one, the script will generate one for you when you build.

## Usage
This is still a full-root script, which means you have to either run `sudo -s` before running the script or just run `sudo ./dvcbs.sh`. 

`sudo -s` has already been done in the installation phase.

`-h`
* Shows the usage page.

`-dm`
* This downloads the latest OTA from DDL's servers and mounts it in ./oskrlatest.

`-m {dir}`
* example when mounting oskrlatest (if already downloaded): `./dvcbs.sh -m`
* example when mounting OTA in your own directory: `./dvcbs.sh -m otawire`
* This will mount the OTA or apq8009-robot-sysfs.img in the directory you give it. If you used -dm, this will automatically detect the oskrlatest folder and you don't have to provide a dir.

`-b {versionbase} {versioncode} {dir}`
* example when building oskrlatest: `./dvcbs.sh -b 1.8.0 123`
* example when building in your own dir: `./dvcbs.sh -b 1.8.0 123 otawire`
* This builds the OTA or apq8009-robot-sysfs.img in the directory you give it. If you don't have a directory, it will try to find the oskrlatest folder.

`-bt {versionbase} {versioncode} {type} {dir}`
* This builds the OTA or apq8009-robot-sysfs.img in the dirctory you give it, but with a certain build type. whiskey, dev, and oskr are your options.

`-bf {versionbase} {versioncode} {dir}`
* Builds an apq8009-robot-sysfs.img for all targets.
