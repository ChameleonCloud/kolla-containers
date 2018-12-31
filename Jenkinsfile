pipeline {
  agent any
  stages {
    stage('build-container') {
      steps {
        sh 'make horizon-build'
      }
    }
  }
}
