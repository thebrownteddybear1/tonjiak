#!/bin/bash
set -x
openconnect  --protocol=gp --csd-wrapper /usr/libexec/openconnect/hipreport.sh      portal.vpn.broadcom.com -b
