# dvcbs
DDL Vector Custom Build Script

This script is an update on my previous script. This one is a lot more automated, checks for everything I could think of, and is something I could actually see a regular dev using without that much hassle.

This is a bash script, so you have to run it in a Linux environment.

## Installation

`git clone https://github.com/kercre123/dvcbs.git`

`cd dvcbs`

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

## Example build

Now that you are in `sudo -s` and you are in the directory with `dvcbs.sh`, you are ready to make a build.

First, lets get the latest OSKR OTA and mount it. run `./dvcbs.sh -dm`

This makes a `./oskrcurrent` directory with a mounted OSKR OTA in it.

Lets cd into it and edit some things.

`cd oskrcurrent/edits/` This puts you at the root of the OTA.

`nano anki/etc/update-engine.env` This puts you in a text editor. Set "UPDATE_ENGINE_ALLOW_DOWNGRADE" to "True".

`cd ../../` This puts you back in the directory with the ./dvcbs.sh script. ../ means previous directory.

Now we can build. `./dvcbs.sh -b 1.8.0 1`

To put the build on your bot, we will need to SCP in the key.

SSH into him and run `mkdir /data/etc/ota_keys`

Get out of SSH and SCP the key into that /data/etc/ota_keys/ folder.

In a separate terminal, run `sudo ifconfig` to find your IP.

Run `cd oskrcurrent && python3 -m http.server`

SSH back into him and run `/anki/bin/update-engine http://computerip:8000/1.8.0.1.ota -v` (replace computerip with the actual computer's ip)

Once it is done, run `reboot`. He will boot into the OTA you just built!
