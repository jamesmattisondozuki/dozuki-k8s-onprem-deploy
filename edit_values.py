import yaml
import os

HERE = os.path.dirname(__file__)
VALUES_FILE = os.path.join(HERE, "chart", 'values.yaml')

SCALAR_CHANGES = {
    "hostname": {
        "description": "The DNS name your users will use to connect to the Dozuki instance.",
        "default": "example.com"
    },
    "customer": {
        "description": "The name of this deployment. Used only internally by Kubernetes.",
        "default": None
    },
    "evironment": {
        "description": "The environment type. This should be set to 'production'",
        "default": "production"
    }
}

NESTED_CHANGES = {
    "db": [
        {
            "key": "host",
            "description": "The hostname, or IP address, of the MySQL server.",
            "default": None,
        },
        {
            "key": "user",
            "description": "The DB username. It is recommended to use 'root' here.",
            "defaukt": "root"
        },
        {
            "key": "password",
            "description": "The DB password for the user specified",
            "default": None
        }
    ],
    "tls": [
        {
            "key": "cert",
            "description": "The path to the TLS certificate to use for HTTPS connections",
        },
        {
            "key": "key",
            "description": "The path to the TLS key that matches the cert for HTTP connections",
        }
    ],
    "memcached": [
        {
            "key": "host",
            "description": "The DNS name for memcached. This should generally be left as 'memcached'",
            "default": "memcached"
        }
    ],
    "smtp": [
        {
            "key": "enabled",
            "default": False,
            "description": "Enable SMTP for this deployment?"
        },
        {
            "key": "host",
            "default": "",
            "description": "SMTP server hostname"
        }
    ],
    "iamge": [
        {
            "key": "repository",
            "default": "registry.replicated.com/dozukikots/dozuki_onprem",
            "description": "The image name. The default should suffice."
        },
        {
            "key": "tag",
            "default": "e1a772955da4199ff7e361c40575f2e796625bbc.2",
            "description": "The image tag. The default should suffice."
        },
        {
            "key": "pullPolicy",
            "default": "IfNotPresent",
            "description": "Image pull policy. The default value should suffice."
        }
    ]
}


with open(VALUES_FILE) as f:
    ym = yaml.load(f, Loader = yaml.Loader)

for key, item in SCALAR_CHANGES.items():
    if item['default'] is not None:
        default = f"[{item['default']}]"
        r = input(f"{key}:\n  Description: {item['description']}\n  Default: {default}: ")
        if not r:
            ym[key] = item['default']
            print(f"Set {key} to {item['default']}")
    else:
        r = input(f"{key}:\n  Description: {item['description']}: ")
        while not r:
            print("Value required. Try again.")
            r = input(f"{key}:  {item['description']}: ")
