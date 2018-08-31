#! /usr/bin/env bash

# Sets the MiniShift profile for the non-prod cluster
minishift profile set non-prod

# Starts the non-prod cluster
minishift start

# Logs in as admin to create projects
oc login "https://$(minishift ip):8443" -u admin -p admin

# Creates projects for development (n teams, n projects)
oc new-project dev1
oc new-project dev2
# Creates the test project
oc new-project test
# Creates the prod (management) project
oc new-project prod

# Creates the development templates
oc create -f ./environments/dev/dev-pipelines-template.yaml -n dev1
oc create -f ./environments/dev/branch-pipeline-template.yaml -n dev1
oc create -f ./environments/dev/dev-pipelines-template.yaml -n dev2
oc create -f ./environments/dev/branch-pipeline-template.yaml -n dev2

# Creates the test template
oc create -f ./environments/test/external/test-external-image-pipeline-template.yaml -n test
oc create -f ./environments/test/internal/test-pipeline-template.yaml -n test

# Creates the prod template
oc create -f ./environments/prod/prod-pipeline-template.yaml -n prod

# Creates a new cluster role for reading groups in the cluster
oc create -f ./configuration/roles/group-reader.yaml

# Creates new groups
oc adm groups new developers
oc adm groups new testers
oc adm groups new administrators
oc adm groups new test-approvers
oc adm groups new prod-approvers

# Adds users to groups
oc adm groups add-users developers developer1 developer2 developer3 developer4
oc adm groups add-users testers tester1 tester2
oc adm groups add-users administrators administrator1
oc adm groups add-users test-approvers test-approver1 test-approver2
oc adm groups add-users prod-approvers prod-approver1

# Sets permissions

# Allows jenkins service account from test to edit development projects
oc adm policy add-role-to-user edit system:serviceaccount:test:jenkins -n dev1
oc adm policy add-role-to-user edit system:serviceaccount:test:jenkins -n dev2

# Allows jenkins service account to read groups from cluster
oc adm policy add-cluster-role-to-user group-reader system:serviceaccount:test:jenkins
oc adm policy add-cluster-role-to-user group-reader system:serviceaccount:prod:jenkins

# Project memberships
oc adm policy add-role-to-user admin developer1 -n dev1
oc adm policy add-role-to-user admin developer2 -n dev1

oc adm policy add-role-to-user admin developer1 -n dev2
oc adm policy add-role-to-user admin developer2 -n dev2

oc adm policy add-role-to-group admin administrators -n dev1
oc adm policy add-role-to-group admin administrators -n dev2

oc adm policy add-role-to-group admin administrators -n test
oc adm policy add-role-to-group admin administrators -n prod
oc adm policy add-role-to-group edit test-approvers -n test
oc adm policy add-role-to-group edit prod-approvers -n prod
oc adm policy add-role-to-group view developers -n test

oc adm policy add-role-to-user view system:serviceaccount:test:jenkins -n dev1
oc adm policy add-role-to-user view system:serviceaccount:test:jenkins -n dev2
oc adm policy add-role-to-user view system:serviceaccount:prod:jenkins -n test

# Exposes the non-prod cluster registry
minishift addons apply registry-route

# Creates the skopeo image

# Imports the jenkins slave base image
oc import-image jenkins-slave-base-rhel7 --confirm --from=registry.access.redhat.com/openshift3/jenkins-slave-base-rhel7 -n openshift

# Creates an image stream to hold the skopeo image
oc create is skopeo -n openshift

# Creates the build config
oc create -f ./configuration/jenkins/slaves/skopeo/skopeo-bc.yaml -n openshift

# Creates a new build
oc start-build skopeo -n openshift --wait

# Tags the skopeo image in the test project 
oc tag openshift/skopeo:latest skopeo:latest -n test

# Adds a label for the sync plugin to push the image into the test jenkins instance
oc label is skopeo role=jenkins-slave -n test

# Tags the skopeo image in the prod project 
oc tag openshift/skopeo:latest skopeo:latest -n prod

# Adds a label for the sync plugin to push the image into the prod jenkins instance
oc label is skopeo role=jenkins-slave -n prod

# Sets the MiniShift profile for the prod cluster
minishift profile set prod

# Starts the prod cluster
minishift start

# Logs in as admin to create projects
oc login https://$(minishift ip):8443 -u admin -p admin

# Creates the prod project 
oc new-project prod

# Creates an admin service account for deployments, etc
oc create sa admin -n prod
oc adm policy add-role-to-user admin system:serviceaccount:prod:admin -n prod

# Exposes the prod cluster registry
minishift addons apply registry-route
