// Report a commit status to GitHub so the build result shows up on the commit.
// Authenticates as the GitHub App: binding an App credential as username/password
// yields the app ID and a short-lived installation token.
// Never fails the build: a broken notification shouldn't hide the real result.
def setGitHubStatus(String state, String description) {
    withCredentials([usernamePassword(credentialsId: env.GITHUB_APP_CREDENTIALS,
                                      usernameVariable: 'GH_APP_ID',
                                      passwordVariable: 'GH_TOKEN')]) {
        withEnv(["GH_STATE=${state}", "GH_DESCRIPTION=${description}"]) {
            sh '''
                curl -fsS -o /dev/null -X POST \
                    -H "Authorization: Bearer $GH_TOKEN" \
                    -H "Accept: application/vnd.github+json" \
                    "https://api.github.com/repos/$GITHUB_REPO/statuses/$(git rev-parse HEAD)" \
                    -d "{\\"state\\": \\"$GH_STATE\\", \\"context\\": \\"jenkins\\", \\"description\\": \\"$GH_DESCRIPTION\\", \\"target_url\\": \\"$BUILD_URL\\"}" \
                    || echo "WARNING: could not set GitHub commit status"
            '''
        }
    }
}

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
        GITHUB_REPO = 'LausEquites/php-container'
        GITHUB_APP_CREDENTIALS = 'gh-lausequites-app'
    }

    stages {
        stage('Setup buildx') {
            steps {
                setGitHubStatus('pending', 'Build in progress')
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
                                --format '{{ index (index .Image "linux/amd64").Config.Labels "com.lausequites.main-service.version" }}'
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
        success {
            setGitHubStatus('success', 'Image built, tested and pushed')
        }
        unsuccessful {
            setGitHubStatus(currentBuild.currentResult == 'ABORTED' ? 'error' : 'failure',
                            "Build ${currentBuild.currentResult.toLowerCase()}")
        }
    }
}
