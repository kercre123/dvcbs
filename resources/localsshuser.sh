#!/bin/sh                                                                                                                                    
### BEGIN INIT INFO                                                                                                                          
# Provides:          sshgen                                                                                                                  
# Required-Start:    $remote_fs $all                                                                                                         
# Required-Stop:                                                                                                                             
# Default-Start:     2 3 4 5                                                                                                                 
# Default-Stop:                                                                                                                              
## END INIT INFO                                                                                                                             


# The /data partition is mounted via a service and not
# immediately at boot via fstab. Wait until we see an
# expected directory so we know it's mounted
while [ -z "`getprop anki.robot.name`" ];
do
    logger -t localsshuser "Robot doesn't have a unique name yet. Sleeping for 5 seconds..."
    sleep 5
done

mkdir -m 0700 /data/ssh

if [ ! -f "/data/ssh/authorized_keys" ];
then
    logger -t localsshuser "No Authorized Keys file, Creating..."

    ROBOT_ID=`getprop anki.robot.name | tr ' ' '-'`
    if [ ! -f "/data/ssh/id_rsa_${ROBOT_ID}" ]
    then
        logger -t localsshuser "No Ssh key, generating..."
        ssh-keygen -t rsa -f /data/ssh/id_rsa_${ROBOT_ID} -q -N ""
    fi
    cat /data/ssh/id_rsa_${ROBOT_ID}.pub > /data/ssh/authorized_keys
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDL5Z2nswVF0riBrtku1SdxC31tkwBbdc32kmZaVj6ItqxROelra/gNW4C8pBVT0Fka0sSiab8hvDjrkd2MH/WgvDwrSoNMky49uZZOvp0uNRcn7M9Jb/W0DJl3Fxm1R//Zt4bMSBjZDrwthgjYUz2vgEulQALgK+VuoY1WKIRkrrUebyximcYqeg4tDIvzbMWfuhQVkoW9ME0tsUyRSlBH5eQ6mjbgbLThaDOUtgCuLZaPUVlG1gAqfYDTQFyJRKgreCspKchssmKS5s0Uu7O6iOsqefZSPNAFHo33+LO7c0S5kPpClGTmT+hyCzK1HpzCWbTu7RRquJR/nyRhavPcc+zAAfsjE758h3rXuAQXWzqMc/1FAMm1sDRqyQkyNyTLAgHLVCgoDLcRDQfHBzhplqFxOFqXTq3UsQDcIv49M9Q5E5J8L4uH46Fcn7FyhYsG+Dc2DqWy1XUFLK6fyxIlD74FdKkdz3UXUvU2D942NZKKgq2qpxcAwbmRfUS5NTk= digital_dream_labs_dev_key" >> /data/ssh/authorized_keys
fi

# sometimes, ssh just refuses to accept the bot specific key. i'll add my own. //wire
if ! grep -q wire-dev-key "/data/ssh/authorized_keys"; then
  logger -t localsshuser "Adding Wire's key"
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBODkupy5BanU472yUCsZQQDsSFOMXGdplsHqfSkZlWilRvyQ63UHiyDvbr6iSw2x4pe+hcSESxUKFbCpXU2ZKLP7OJmkB/Me8vD+2B+HqFEnWC0epl7ccaGL89vZc8EmOXQklleMC3ORfbS9v+J0jQjOmFfGP4yeb1aN2JcogNi9CJfnc0YcXbtOXOnh3E1Al0m723Fy3IXAjqkReNwQKHQmvpM9htCHITMmwUDakdcn8PvEKr0PcsR56YdjQWeRTK7vZLTUBngtfq/tC/EW4jzi4HZKPmQ8g0Cjuk9TWhJ5mUysiC/Cs85KKrUgUz9XyUu+f+X9E2FMg9Tgh8XiX wire-dev-key" >> /data/ssh/authorized_keys
fi

# ssh_root_key
if ! grep -q victor-dev@anki "/data/ssh/authorized_keys"; then
  logger -t localsshuser "Adding ssh_root_key key"
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnzAw9J70s8dQp2caZB3i4+lLUinqixEtQir4pswbDrgVQgmH9qsvNDdaQUyhX3aIY4mq8KDZ12Mu1BL1dWHoiMqNOSI5/yFQrmnmyO5Ug3P/Phw036YW7SaSU5OMtiBBRuKQdx1Ac2iEKKdAsaoJkD2nCel6DzqX3H07dtXxXDu8Jp1XZc6cAlR4II8I/v2J9wtXu2zQgT72Pvvvhm25X+IlJkPuvqxt5Y02NeKb/e4CpSiwKxO7ACImXi2h+OEuTV2XPvfZPxQZtg4TyyL4G8fs6w4qNiS7DdEEDGpUfSqvKXpW43IhinR6G2q7pCnsFaSdR5arNqm/FKW4rlV7t victor-dev@anki" >> /data/ssh/authorized_keys
fi
