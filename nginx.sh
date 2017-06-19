#!/usr/bin/env bash

if [ "x${1}" == "xdeploy" ]; then
	read hostname hostaddr <<< "${2}"
	rsync -e 'ssh -q -F/dev/null -oPasswordAuthentication=no -oKbdInteractiveAuthentication=no -oChallengeResponseAuthentication=no -oUseRoaming=no -oStrictHostKeyChecking=no -oConnectTimeout=60 -oServerAliveCountMax=120 -oServerAliveInterval=1 -oControlPath=/tmp/%r@%h:%p -oControlMaster=auto -oControlPersist=yes' -a --numeric-ids --delete /root/nginx/ "root@${hostaddr}:/etc/nginx/" 2>&1 | sed "s|^|${hostname} ${hostaddr} |"
	ssh -n -q -F/dev/null -oPasswordAuthentication=no -oKbdInteractiveAuthentication=no -oChallengeResponseAuthentication=no -oUseRoaming=no -oStrictHostKeyChecking=no -oConnectTimeout=60 -oServerAliveCountMax=120 -oServerAliveInterval=1 -oControlPath=/tmp/%r@%h:%p -oControlMaster=auto -oControlPersist=yes "root@${hostaddr}" "systemctl reload nginx.service" 2>&1 | sed "s|^|${hostname} ${hostaddr} |"
	echo "${hostname} ${hostaddr} done"
	exit
fi

node nginx.js > /root/nginx/nginx.conf && fgrep neighbor /etc/bird/peers/v4/fvz-arec-*-*-*.conf | sed -r 's!/etc/bird/peers/v4/(fvz-arec-..-...-..)\.conf:\tneighbor ([0-9\.]+);!\1 \2!' | xargs -n1 -P0 -I% bash "${0}" "deploy" "%"
