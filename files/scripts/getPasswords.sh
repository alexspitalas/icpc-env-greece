#!/bin/bash

IP="192.168.31.200"
Port="8000"

curl http://$IP:$Port/passwords.txt > passwords.txt