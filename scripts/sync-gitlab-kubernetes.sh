#!/bin/bash

git clone git@${1}:kubernetes/kubernetes.git /tmp/k8s
cd /tmp/k8s
if [[ $? -ne 0 ]]; then
    echo 'Git clone failed'
    exit 1
else
    echo 'Clone successful'
fi
git remote add github https://github.com/kubernetes/kubernetes.git
git fetch github -a
git pull github master
K8S_NIGHTLY=$(curl https://storage.googleapis.com/kubernetes-release-dev/ci-cross/latest.txt)
git reset ${K8S_NIGHTLY#*+}
git push --force --all
git push --tags --force
