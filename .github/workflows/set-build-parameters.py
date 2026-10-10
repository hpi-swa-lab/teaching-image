#!/usr/bin/env python
import os, sys, yaml

with open(".github/workflows/main.yml") as f:
    workflow = yaml.load(f, Loader=yaml.BaseLoader)

defaults = workflow["on"]["workflow_dispatch"]["inputs"]

supplied = json.loads(os.environ.get(sys.argv[1], "{}"))

def value(name):
    return supplied[name] or defaults[name]["default"]

lecture = value("lecture")
year = value("year")
release = value("squeak-release")
build = value("squeak-build")
osvm = value("osvm-build")

values = {
    "LECTURE": lecture,
    "YEAR": year,
    "RELEASE": release,
    "PATCH": build,
    "BUNDLE_RELEASE": release,
    "BUNDLE_PATCH": build,
    "OSVM_BUILD": osvm,
}

with open(os.environ["GITHUB_ENV"], "a") as env:
    for key, val in values.items():
        env.write(f"{key}={val}\n")
