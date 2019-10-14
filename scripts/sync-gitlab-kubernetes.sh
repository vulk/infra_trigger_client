#!/bin/bash

git clone git@${1}:kubernetes/kubernetes.git /tmp/k8s
pushd /tmp/k8s
git remote add github https://github.com/kubernetes/kubernetes.git
git pull github master
K8S_NIGHTLY=$(curl https://storage.googleapis.com/kubernetes-release-dev/ci-cross/latest.txt)
git reset ${K8S_NIGHTLY#*+}
git push --force
