#!/bin/bash
# this is wire's script to get otas upload to the server

set -e

if [ -f .env ]; then
  export $(cat .env | xargs)
else
  touch .env
  echo "SERVER_IP=" > .env
  echo "SERVER_KEY=" >> .env
  echo "wwwroot=" >> .env
  echo ".env created. Fill it out then run this script again. Don't put a / after wwwroot."
  exit 0
fi

sshcommand="ssh -i ${SERVER_KEY} root@${SERVER_IP}"
base=$2
code=$3
#unstable, stable, or test
branch=$1
origdir=$4

if [ ! -f ${SERVER_KEY} ]; then
   echo "no server key found in ${SERVER_KEY}"
   exit 0
fi

if [ -z ${base} ] || [ -z ${code} ] || [ -z ${branch} ]; then
   echo "Example use: ./upload stable 1.8.0 123"
   exit 0
fi

if [ ! ${branch} == stable ]; then
if [ ! ${branch} == unstable ]; then
if [ ! ${branch} == test ]; then
   echo "Branch invalid. Choices are: stable, unstable, test."
   exit 0
fi
fi
fi

echo "${base}.${code}.ota will be SCPed to root@${SERVER_IP} with ${SERVER_KEY} if it exists"

if [ -f all/whiskeyfinal/${base}.${code}.ota ] && [ -f all/devfinal/${base}.${code}.ota ] && [ -f all/oskrfinal/${base}.${code}.ota ] && [ -f all/oskrnsfinal/${base}.${code}.ota ]; then
      ${sshcommand} "mkdir -p ${wwwroot}/whiskey-stable/diff ${wwwroot}/whiskey-unstable/diff ${wwwroot}/dev-stable/diff ${wwwroot}/dev-unstable/diff ${wwwroot}/oskr-stable/diff ${wwwroot}/oskr-unstable/diff ${wwwroot}/oskrns-stable/diff ${wwwroot}/oskrns-unstable/diff"
#these are for if i am testing otas for personal use
      ${sshcommand} "mkdir -p ${wwwroot}/whiskey-test"
      ${sshcommand} "mkdir -p ${wwwroot}/dev-test"
      ${sshcommand} "mkdir -p ${wwwroot}/oskr-test"
      ${sshcommand} "mkdir -p ${wwwroot}/oskrns-test"
      scp -i ${SERVER_KEY} all/whiskeyfinal/${base}.${code}.ota ${SERVER_IP}:${wwwroot}/whiskey-${branch}/
      scp -i ${SERVER_KEY} all/devfinal/${base}.${code}.ota ${SERVER_IP}:${wwwroot}/dev-${branch}/
      scp -i ${SERVER_KEY} all/oskrfinal/${base}.${code}.ota ${SERVER_IP}:${wwwroot}/oskr-${branch}/
      scp -i ${SERVER_KEY} all/oskrnsfinal/${base}.${code}.ota ${SERVER_IP}:${wwwroot}/oskrns-${branch}/
      if [ ! ${branch} == test ]; then
         ${sshcommand} "rm -f ${wwwroot}/whiskey-${branch}/latest.ota ${wwwroot}/dev-${branch}/latest.ota ${wwwroot}/oskr-${branch}/latest.ota ${wwwroot}/oskrns-${branch}/latest.ota"
         ${sshcommand} "ln -s ${wwwroot}/whiskey-${branch}/${base}.${code}.ota ${wwwroot}/whiskey-${branch}/latest.ota"
         ${sshcommand} "ln -s ${wwwroot}/dev-${branch}/${base}.${code}.ota ${wwwroot}/dev-${branch}/latest.ota"
         ${sshcommand} "ln -s ${wwwroot}/oskr-${branch}/${base}.${code}.ota ${wwwroot}/oskr-${branch}/latest.ota"
         ${sshcommand} "ln -s ${wwwroot}/oskrns-${branch}/${base}.${code}.ota ${wwwroot}/oskrns-${branch}/latest.ota"
      fi
# auto-updating stuff
      if [ ${branch} == stable ]; then
         if [ ! -z ${origdir} ]; then
            if [ -f ${origdir}lastversion ]; then
               export $(cat ${origdir}lastversion | xargs)
               echo "Doing auto-updating stuff"
               ${sshcommand} "ln -s ${wwwroot}/whiskey-${branch}/latest.ota ${wwwroot}/whiskey-${branch}/diff/${lastbase}.${lastcode}.ota"
               ${sshcommand} "ln -s ${wwwroot}/oskr-${branch}/latest.ota ${wwwroot}/oskr-${branch}/diff/${lastbase}.${lastcode}.ota"
               ${sshcommand} "ln -s ${wwwroot}/oskrns-${branch}/latest.ota ${wwwroot}/oskrns-${branch}/diff/${lastbase}.${lastcode}.ota"
               ${sshcommand} "ln -s ${wwwroot}/dev-${branch}/latest.ota ${wwwroot}/dev-${branch}/diff/${lastbase}.${lastcode}.ota"
            fi
         fi
      fi
# changelog
      if [ ! ${branch} == test ]; then
         ${sshcommand} "echo '<h2>${base}.${code}</h2>' > ${wwwroot}/oskr-stable/changelog-temp"
         ${sshcommand} "echo '<p>put stuff here</p>' >> ${wwwroot}/oskr-stable/changelog-temp"
         ${sshcommand} "echo '<hr>' >> ${wwwroot}/oskr-stable/changelog-temp"
         ${sshcommand} "cp ${wwwroot}/oskr-stable/changelog.html ${wwwroot}/oskr-stable/changelog.html-backup"
         ${sshcommand} 'echo $(cat /var/www/html/oskr-stable/changelog.html-backup) >> /var/www/html/oskr-stable/changelog-temp'
         ${sshcommand} "mv ${wwwroot}/oskr-stable/changelog-temp ${wwwroot}/oskr-stable/changelog.html"
         ssh -i ${SERVER_KEY} -t root@${SERVER_IP} "nano /var/www/html/oskr-stable/changelog.html; exec \$SHELL -l && logout"
     fi
else
      echo "The OTAs with the base and code you provided don't exist. You must build with -bf."
fi
