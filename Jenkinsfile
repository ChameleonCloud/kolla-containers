pipeline {
  agent any

  environment {
    DOCKER_REGISTRY = 'docker.chameleoncloud.org'
    DOCKER_REGISTRY_CREDS = credentials('kolla-docker-registry-creds')
  }

  parameters {
    string(name: 'PROJECT_NAME', defaultValue: '', description: 'The upstream project name', trim: true)
    string(name: 'BRANCH_NAME', defaultValue: '', description: 'The upstream branch name', trim: true)
  }

  stages {
    stage('docker-setup') {
      steps {
        sh 'docker login --username=$DOCKER_REGISTRY_CREDS_USR --password=$DOCKER_REGISTRY_CREDS_PSW $DOCKER_REGISTRY'
      }
    }

    stage('build') {
      environment {
        ESCAPED_BRANCH_NAME = """${sh(
          returnStdout: true,
          script: "echo -n '${params.BRANCH_NAME}' | sed 's/\\//%2F/g'"
        )}"""
      }

      steps {
        copyArtifacts(projectName: "${params.PROJECT_NAME}/${env.ESCAPED_BRANCH_NAME}",
                      target: "${env.WORKSPACE}/sdist/${params.PROJECT_NAME}",
                      selector: upstream(fallbackToLastSuccessful: true))
        sh "make ${params.PROJECT_NAME}-build"
      }
    }

    stage('publish') {
      steps {
        sh "make ${params.PROJECT_NAME}-publish"
        sh 'docker logout $DOCKER_REGISTRY'
      }
    }
  }
}
