#! /usr/bin/env bash

minishift profile set prod
minishift delete -f

minishift profile set non-prod
minishift delete -f

rm -rf $HOME/.minishift
rm -rf $HOME/.kube
