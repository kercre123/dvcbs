#!/bin/bash

set -e

# this is wire's script to get otas upload to the server
SERVER_IP=192.168.1.2
SERVER_KEY=/thekeyofvictro
sshcommand="ssh -i ${SERVER_KEY} root@${SERVER_IP}"
wwwroot=/var/www/html
base=$1
code=$2
#unstable, stable, or test
branch=$3

if [ ! -f ${SERVER_KEY} ]; then
   echo "no server key found in ${SERVER_KEY}"
   exit 0
fi

if [ -z ${base} ] || [ -z ${code} ] || [ -z ${branch} ]; then
   echo "Example use: ./upload 1.8.0 123 stable"
   exit 0
fi

if [ ! ${branch} == "test" ] || [ ! ${branch} == "stable" ] || [ ! ${branch} == "unstable" ]; then
   echo "Branch invalid. Choices are: stable, unstable, test."
   exit 0
fi

echo "${base}.${code}.ota will be SCPed to root@${SERVER_IP} with ${SERVER_KEY} if it exists"

if [ -f all/whiskeyfinal/${base}.${code}.ota ] && [ -f all/devfinal/${base}.${code}.ota ] && [ -f all/oskrfinal/${base}.${code}.ota ] && [ -f all/oskrnsfinal/${base}.${code}.ota ]; then
      ${sshcommand} "mkdir -p ${wwwroot}/whiskey-stable/diff"
      ${sshcommand} "mkdir -p ${wwwroot}/whiskey-unstable/diff"
      ${sshcommand} "mkdir -p ${wwwroot}/dev-stable/diff"
      ${sshcommand} "mkdir -p ${wwwroot}/dev-unstable/diff"
      ${sshcommand} "mkdir -p ${wwwroot}/oskr-stable/diff"
      ${sshcommand} "mkdir -p ${wwwroot}/oskr-unstable/diff"
      ${sshcommand} "mkdir -p ${wwwroot}/oskrns-stable/diff"
      ${sshcommand} "mkdir -p ${wwwroot}/oskrns-unstable/diff"
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
         ${sshcommand} "rm -f ${wwwroot}/whiskey-${branch}/latest.ota"
         ${sshcommand} "rm -f ${wwwroot}/dev-${branch}/latest.ota"
         ${sshcommand} "rm -f ${wwwroot}/oskr-${branch}/latest.ota"
         ${sshcommand} "rm -f ${wwwroot}/oskrns-${branch}/latest.ota"
         ${sshcommand} "ln -s ${wwwroot}/whiskey-${branch}/${base}.${code}.ota ${wwwroot}/whiskey-${branch}/latest.ota"
         ${sshcommand} "ln -s ${wwwroot}/dev-${branch}/${base}.${code}.ota ${wwwroot}/dev-${branch}/latest.ota"
         ${sshcommand} "ln -s ${wwwroot}/oskr-${branch}/${base}.${code}.ota ${wwwroot}/oskr-${branch}/latest.ota"
         ${sshcommand} "ln -s ${wwwroot}/oskrns-${branch}/${base}.${code}.ota ${wwwroot}/oskrns-${branch}/latest.ota"
      fi
else
      echo "The OTAs with the base and code you provided don't exist. You must build with -bf."
fi
   
