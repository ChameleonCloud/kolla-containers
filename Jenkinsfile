pipeline {
  agent any

  parameters {
    string(name: 'SERVICE_NAME', defaultValue: '', trim: true,
           description: 'The OpenStack service name')
    string(name: 'JOB_NAME', defaultValue: '', trim: true,
           description: 'If building from upstream Jenkins job, the upstream job name')
  }

  environment {
    DOCKER_REGISTRY = 'docker.chameleoncloud.org'
    DOCKER_REGISTRY_CREDS = credentials('kolla-docker-registry-creds')
  }

  stages {
    stage('docker-setup') {
      steps {
        sh 'docker login --username=$DOCKER_REGISTRY_CREDS_USR --password=$DOCKER_REGISTRY_CREDS_PSW $DOCKER_REGISTRY'
      }
    }

    stage('build') {
      when {
        expression { params.JOB_NAME == '' }
      }

      steps {
        sh "make ${env.SERVICE_NAME}-build"
      }
    }

    stage('build-from-upstream') {
      when {
        expression { params.JOB_NAME != '' }
      }

      environment {
        SERVICE_NAME = """${sh(
          returnStdout: true,
          script: "echo '${params.JOB_NAME}' | cut -d/ -f1 | tr -d '\n'"
        )}"""
      }

      steps {
        copyArtifacts(projectName: "${params.JOB_NAME}",
                      target: "${env.WORKSPACE}/sources",
                      selector: upstream(fallbackToLastSuccessful: true))
        sh "make ${env.SERVICE_NAME}-build-locals"
      }
    }

    stage('publish') {
      steps {
        sh "make ${env.SERVICE_NAME}-publish"
      }
    }
  }

  post {
    always {
      sh 'docker logout $DOCKER_REGISTRY'
    }
  }
}
