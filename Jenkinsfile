pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        REGISTRY   = 'ghcr.io'
        IMAGE      = 'ghcr.io/lausequites/php-container/php8.5'
        PLATFORMS  = 'linux/amd64,linux/arm64'
        BUILDER    = 'php-container-builder'
    }

    stages {
        stage('Setup buildx') {
            steps {
                sh '''
                    docker run --privileged --rm tonistiigi/binfmt --install arm64,amd64
                    docker buildx inspect "$BUILDER" >/dev/null 2>&1 \
                        || docker buildx create --name "$BUILDER" --driver docker-container
                    docker buildx use "$BUILDER"
                    docker buildx inspect --bootstrap
                '''
            }
        }

        stage('Login') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'gh-pat',
                                                  usernameVariable: 'GHCR_USER',
                                                  passwordVariable: 'GHCR_TOKEN')]) {
                    sh 'echo "$GHCR_TOKEN" | docker login "$REGISTRY" -u "$GHCR_USER" --password-stdin'
                }
            }
        }

        stage('Build & push') {
            steps {
                sh '''
                    SHORT_SHA=$(git rev-parse --short HEAD)
                    docker buildx build . \
                        --platform "$PLATFORMS" \
                        -t "$IMAGE:latest" \
                        -t "$IMAGE:$SHORT_SHA" \
                        --push
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout "$REGISTRY" || true'
        }
    }
}
