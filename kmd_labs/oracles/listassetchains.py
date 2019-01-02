#!/usr/bin/env python2
import os
import json

#script_dir = os.getcwd()
HOME = os.environ['HOME']
with open(HOME + '/StakedNotary/assetchains.json') as file:
    assetchains = json.load(file)

for chain in assetchains:
    print(chain['ac_name'])
