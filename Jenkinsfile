pipeline {
  agent any
  stages {
    stage('build-container') {
      environment {
        DOCKER_REGISTRY = 'docker.chameleoncloud.org'
        DOCKER_REGISTRY_CREDS = credentials('kolla-docker-registry-creds')
      }
      steps {
        sh 'docker login --username=$DOCKER_REGISTRY_CREDS_USR --password=$DOCKER_REGISTRY_CREDS_PSW $DOCKER_REGISTRY'
        sh 'make horizon-build'
        sh 'make horizon-publish'
        sh 'docker logout $DOCKER_REGISTRY'
      }
    }
  }
}
