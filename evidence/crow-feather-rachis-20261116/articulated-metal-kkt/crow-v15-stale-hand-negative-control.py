#!/usr/bin/python3
import json
p=json.load(open("/private/tmp/crow-articulated-hand-response.json"))
p["M"][0] += .01
print(json.dumps(p))
