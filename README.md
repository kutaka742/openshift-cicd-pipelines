# OpenShift CI/CD Pipelines

Basic demonstration of OpenShift CI/CD pipelines for deploying applications across environments using advanced deployment strategies like Blue/Green.

The pipelines use the new declarative approach and the [OpenShift Jenkins Pipeline Plugin](https://github.com/openshift/jenkins-client-plugin).

## Pipelines

### CI

![CI](./demo/images/pipeline-ci.png)

### CD

![CD](./demo/images/pipeline-cd.png)

## Pipeline Library

The pipelines use a shared library for common functionality, the library is embedded in this repository but can be externalized in other Git repository as well.

## Demo

### Create the environments

These are the environments used to promote the application:

    oc new-project dev
    oc new-project test
    oc new-project prod
    
### Create a Jenkins instance

A Jenkins instances is created in the development project:

    oc new-app --template=jenkins-ephemeral --name=jenkins -n dev

Then a set of permissions need to be granted:

    oc adm policy add-role-to-user edit system:serviceaccount:dev:jenkins -n test
    oc adm policy add-role-to-user edit system:serviceaccount:dev:jenkins -n prod

### Create the pull Secret (optional)

If the repository used is private a pull Secret is needed.

The Secret needs to be label with **credential.sync.jenkins.openshift.io=true** to be synchronized in Jenkins thanks to the [OpenShift Jenkins Sync Plugin](https://github.com/openshift/jenkins-sync-plugin). 

An annotation is used to automatically assign the Secret to any BuildConfig that matches the Git URI used.

The commands to create and label the Secret are:

    oc create secret generic repository-credentials --from-file=ssh-privatekey=$HOME/.ssh/id_rsa --type=kubernetes.io/ssh-auth -n dev
    oc label secret repository-credentials credential.sync.jenkins.openshift.io=true -n dev
    oc annotate secret repository-credentials 'build.openshift.io/source-secret-match-uri-1=ssh://github.com/*' -n dev

### Create the pipelines

A pipeline is a special type of BuildConfig so to create it the new-build command is used:

#### CI 

    oc new-build ssh://git@github.com/redhatcsargentina/openshift-cicd-pipelines.git --name=hello-service-ci-pipeline --context-dir=./pipelines/ci --strategy=pipeline -e APP_NAME=hello-service-ci -n dev
    
#### CD

    oc new-build ssh://git@github.com/redhatcsargentina/openshift-cicd-pipelines.git --name=hello-service-cd-pipeline --context-dir=./pipelines/cd --strategy=pipeline -e APP_NAME=hello-service -n dev

After the execution of this commands the pipelines are started.

### With Templates

Another method is with Templates:

    oc create -f ./pipelines/ci/ci-pipeline.yaml -n dev
    oc create -f ./pipelines/cd/cd-pipeline.yaml -n dev

Then the following commands create the pipelines:

    oc new-app --template ci-pipeline --name=hello-service-ci-pipeline -p APP_NAME=hello-service-ci -p GIT_REPO=ssh://git@github.com/redhatcsargentina/openshift-cicd-pipelines.git -p GIT_BRANCH=master

    oc new-app --template cd-pipeline --name=hello-service-pipeline -p APP_NAME=hello-service -p GIT_REPO=ssh://git@github.com/redhatcsargentina/openshift-cicd-pipelines.git -p GIT_BRANCH=master