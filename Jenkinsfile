pipeline {
    agent { label 'docker-agent' }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    triggers {
        // Build on every push to main. Requires a GitHub webhook pointing at
        // <jenkins-url>/github-webhook/ (push events) and the job's branch set to main.
        githubPush()
        // Weekly rebuild to pick up base image and package updates
        cron('H H * * 0')
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

        stage('Test') {
            steps {
                // Build for the agent's native platform only, load it locally and smoke test it
                // before anything is pushed. Layers are cached by the builder for the push below.
                sh '''
                    docker buildx build . --pull --load -t "php-container:test-$BUILD_NUMBER"
                    ./tests/smoke-test.sh "php-container:test-$BUILD_NUMBER"
                '''
            }
            post {
                always {
                    sh 'docker rmi "php-container:test-$BUILD_NUMBER" || true'
                }
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
                        --pull \
                        --build-arg GIT_COMMIT="$(git rev-parse HEAD)" \
                        --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        -t "$IMAGE:latest" \
                        -t "$IMAGE:$SHORT_SHA" \
                        --push
                '''
            }
        }

        stage('Report PHP version') {
            steps {
                script {
                    def phpVersion = sh(
                        returnStdout: true,
                        script: '''
                            docker buildx imagetools inspect "$IMAGE:$(git rev-parse --short HEAD)" \
                                --format '{{ index (index .Image "linux/amd64").Config.Labels "com.heynabo.main-service.version" }}'
                        '''
                    ).trim()
                    echo "Built PHP version: ${phpVersion}"
                    currentBuild.description = "PHP ${phpVersion}"
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout "$REGISTRY" || true'
        }
    }
}
