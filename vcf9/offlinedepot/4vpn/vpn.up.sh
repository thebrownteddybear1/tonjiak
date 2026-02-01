#!/bin/bash
set -x
openconnect -u 'ty036880@broadcom.net'      --protocol=gp --csd-wrapper /usr/libexec/openconnect/hipreport.sh      portal.vpn.broadcom.com -b
