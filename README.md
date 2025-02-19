# dozuki-k8s-onprem-deploy

## Description:
This repository contains manifests ad scripts to setup an on-prem Dozuki deployment.

## Requirements

- A vanilla node/VM running one of the supported operating systems
- A vanilla node/VM running MySQL server _or_ a cloud-hosted MySQL server (such as RDS)

#### Node Requirements

| Component | Requirement | Notes |
| --------- | ----------- | ----- |
| CPU Cores | 2+          |       |
| RAM       | 16GB        | Using 24GB is strongly recommended!
| HDD1      | 20GB        | For the OS install |
| HDD2      | 250GB

## Supported Operating Systems

These manifests / scripts have been extensively tested on the following operating systems:

| OS            | Version | 
| ------------- | --------|
| RedHat Linux  | 9.5     |
| Ubuntu Linux  | 22.04   |

