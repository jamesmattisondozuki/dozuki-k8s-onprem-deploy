#!/usr/bin/env python3

#
#
#

import subprocess
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("disk1", action = "store", help = "Path to the first, smaller disk to use as the default PV")
parser.add_argument("disk2", action = "store", help = "Path to the first, larger  disk to use as the minio PV")
parser.add_argument("-p", "--partition-flag", action = "store_true", help = "Use p1 as the partition format as opposed to 1", default = False)

args = parser.parse_args()

partition_targets = []
for disk in [args.disk1, args.disk2]:

    proc = subprocess.Popen(f"fdisk {disk}", shell = True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    proc.stdin.write("n\n")
    proc.stdin.write("p\n")
    proc.stdin.write("\n")
    proc.stdin.write("\n")
    proc.stdin.write("\n")
    proc.stdin.write("w\n")

    o, e = proc.communicate()

    if proc.returncode != 0:
        raise Exception(f"Failed to create partition on {disk}")
    
    print(o)

    print("Formatting disk...")
    
    if args.partition_flag:
        s = "p1"
    else:
        s = "1"
    
    partition_target = f"{disk}{s}"
    partition_targets.append(partition_target)

    subprocess.run(f"mkfs.ext4 {partition_target}", shell = True)

subprocess.run("mkdir -p /mnt/minio /mnt/dozuki-default", shell = True)
subprocess.run(f"mount {partition_targets[0]} /mnt/dozuki-default", shell = True)
subprocess.run(f"mount {partition_targets[1]} /mnt/minio", shell = True)


print("Now, change volume.yaml and kubectl apply it.")
