import subprocess
import yaml
import os


s = ""
i = 0
with open("manifest.yaml", "r") as _o:
    for line in _o.readlines():
        if not "---" in line:
            s += line + "\n"
        else:
            print(f"Writing {i}.yaml")
            if not s.strip().strip("\n"):
                continue
            with open(f"tmp/{i}.yaml", "w") as _o:
                _o.write(s)
            i += 1
            s = ""

yamls = os.listdir("tmp")

for ob in yamls:
    print(f"Checking: {ob}")
    with open(f"tmp/{ob}", "r") as _o:
        ym = yaml.load(_o, Loader = yaml.Loader)
        if not "apiVersion" in ym.keys():
            print(f"Didn't find API version for {ob}")


