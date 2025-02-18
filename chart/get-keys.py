import yaml

with open("values.yaml", "r") as _o:
    ym = yaml.load(_o, Loader = yaml.Loader)


for k in ym.keys():
    print(f" - {k} ")
