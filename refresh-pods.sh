#!/bin/bash

for POD in $( kubectl get po --no-headers | awk '{ print $1 }' | xargs ); do 
	echo Deleting $POD ...
	timeout 3 kubectl delete pod $POD
done
