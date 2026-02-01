#!/bin/bash
set -x
ps aux | grep -v -e defunct -e grep | grep openconnect | awk '{print $2}' | xargs kill -9
