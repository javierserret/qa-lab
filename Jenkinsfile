pipeline {
    agent none

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {
        string(name: 'ANDROID_SOURCE_REV', defaultValue: 'af2c8307b948edba8746c9e300dc400dc7dd53b4', description: 'Full commit SHA in the Android app fork')
        string(name: 'ANDROID_SYSTEM_IMAGE', defaultValue: 'system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a', description: 'Installed SDK image on the Mac agent')
    }

    stages {
        stage('API and web') {
            // Temporary: keep existing Docker networking until a web agent is provisioned.
            agent { label 'built-in' }
            stages {
                stage('Verify tools') {
                    steps {
                        sh 'node -v'
                        sh 'npm -v'
                    }
                }

                stage('Install dependencies') {
                    steps {
                        dir ('automation/playwright') {
                            sh 'npm ci'
                        }
                    }
                }

                stage('Install Playwright browsers') {
                    steps {
                        dir ('automation/playwright') {
                            sh 'npx playwright install'
                        }
                    }
                }

                stage('Run API tests') {
                    steps {
                        dir ('automation/postman') {
                            sh 'npm ci'
                            sh 'npm test -- --env-var baseUrl=http://backend-api:3001'
                        }
                    }
                }

                stage('Run Playwright tests') {
                    steps {
                        dir ('automation/playwright') {
                            sh 'BASE_URL=http://frontend-app:5173 npx playwright test'
                        }
                    }
                }
            }
            post {
                always {
                    junit testResults: 'automation/playwright/test-results/results.xml,automation/postman/test-results/results.xml'
                    archiveArtifacts artifacts: 'automation/postman/test-results/**', allowEmptyArchive: true
                    archiveArtifacts artifacts: 'automation/playwright/playwright-report/**', allowEmptyArchive: true
                    archiveArtifacts artifacts: 'automation/playwright/test-results/**', allowEmptyArchive: true
                }
            }
        }

        stage('Android build and test') {
            agent { label 'android' }
            options { timeout(time: 30, unit: 'MINUTES') }
            steps {
                deleteDir()
                checkout scm
                sh 'bash ci/android/run.sh'
            }
            post {
                always {
                    junit testResults: 'automation/appium/test-results/junit/*.xml', allowEmptyResults: true
                    archiveArtifacts artifacts: 'ci-artifacts/android/**,automation/appium/test-results/**', allowEmptyArchive: true, fingerprint: true
                }
            }
        }
    }
}
