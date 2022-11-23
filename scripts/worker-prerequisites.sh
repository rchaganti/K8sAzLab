#!/bin/sh
sudo ufw allow proto tcp from any to any port 10250,10257,10259,179,30000:32767
