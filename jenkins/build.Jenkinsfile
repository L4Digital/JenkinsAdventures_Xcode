#!groovy

// Working Node likely master for single node setups
xcodeNode = 'xcode8'

// For xcodebuild
env.LANG = 'en_US.UTF-8'

// Export Options Plist
l4Plist = 'jenkins/l4.plist'
xcodeProject = 'JenkinsAdventures.xcodeproj'
xcodeReleaseScheme = 'JenkinsAdventures'
xcodeReleaseTarget = 'JenkinsAdventures'
xcodeTestScheme = 'JenkinsAdventures'
xcodeReleaseBuildConfig = 'Release'

xcodeTestDestination = 'platform=iOS Simulator,name=iPhone 6'

// Used to save per build artifacts
stashes = []

// Credentials for Keychains, Xcode Signing Identity, Keychain passwords, and provisioning profiles
credentials = [
        file(credentialsId: 'L4_Enterprise_Keychain', variable: 'L4_ENTERPRISE_KEYCHAIN'),
        file(credentialsId: 'Jenkins_Adventures_In_House.mobileprovision', variable: 'JENKINS_ADVENTURES_IN_HOUSE'),
        usernamePassword(
                credentialsId: 'L4_Enterprise_Keychain_Info',
                passwordVariable: 'L4_ENTERPRISE_KEYCHAIN_PASSWORD',
                usernameVariable: 'L4_ENTERPRISE_KEYCHAIN_IDENTITY'
        )
]

// Get the UUID from the provisioning profile
def getUuid(String provisioningProfileVariable) {
    uuid = sh returnStdout: true, script: "grep UUID -A1 -a '${env[provisioningProfileVariable]}' | grep -io \"[-A-Z0-9]\\{36\\}\""
    uuid.trim()
}

// Moves provisioning profile to path set by the node PROVISIONING_PROFILES
// Feel free to use "/Users/osx/Library/MobileDevice/Provisioning Profiles" as a default path
def installProvisioningProfile(String provisioningProfileVariable) {
    sh "cp -f ${env[provisioningProfileVariable]} '${env['PROVISIONING_PROFILES']}/${getUuid(provisioningProfileVariable)}.mobileprovision'"
}

def test(String stageName, String testScheme) {
    stage(stageName) {
        node(xcodeNode) {
            checkout scm

            sh """xcodebuild clean test \
            -scheme '${testScheme}' \
            -project '${xcodeProject}' \
            -destination '${xcodeTestDestination}' \
            -sdk iphonesimulator | xcpretty --report junit"""

            def stashKeyTest = "${stageName.replaceAll(' ', '_')}_TEST"
            stash includes: 'build/reports/*.xml', name: stashKeyTest
            stashes.push(stashKeyTest)

            junit 'build/reports/*.xml'
        }
    }
}

def build(String stageName, String keychain, String keychainPassword, String signingStyle, String signingIdentity, String plistPath, String appPP) {
    stage(stageName) {
        node(xcodeNode) {
            checkout scm

            withCredentials(credentials) {
                installProvisioningProfile(appPP)

                // Define Export Archive Name
                def xcodeArchive = "${xcodeReleaseScheme.replace(' ', '_')}_${signingStyle}.xcarchive"

                // Unlock Keychain, append build number (Jenkins BUILD_NUMBER)
                // set signing provisioning style to manual, feel free to use any other tool to do this work
                sh """jenkinsutil --xcode-project '${xcodeProject}' \
                --xcode-target '${xcodeReleaseTarget}' \
                --xcode-build-configuration  '${xcodeReleaseBuildConfig}' \
                --xcode-append-bundle-version ${env.BUILD_NUMBER} \
                --xcode-set-manual-provisioning-style \
                --keychain '${env[keychain]}' \
                --keychain-password '${env[keychainPassword]}'"""

                // Xcode Archive
                sh """xcodebuild clean archive \
                -project '${xcodeProject}' \
                -scheme '${xcodeReleaseScheme}' \
                -archivePath ${xcodeArchive} \
                CODE_SIGN_IDENTITY='${env[signingIdentity]}' \
                PROVISIONING_PROFILE=${getUuid(appPP)} \
                REQUIRE_UPLOAD_SUCCESS=0 \
                DEVELOPMENT_TEAM=\$(jenkinsutil --xcode-get-team-id '${plistPath}')"""

                // Due to appending the build number, we will generate a build name from the archive
                def buildName = sh returnStdout: true, script: "jenkinsutil --xcode-get-build-name ${xcodeArchive}/Info.plist"
                buildName = buildName.trim()

                // Sign and export to ipa
                sh """xcodebuild -exportArchive \
                -exportOptionsPlist '${plistPath}' \
                -archivePath ${xcodeArchive} \
                -exportPath '${buildName}_${signingStyle}'"""

                // Zip up the archive to make sure we preserve debug symbols
                sh "zip -r ${xcodeArchive}.zip ${xcodeArchive}"

                // Unique Stash names for the zip and ipa
                def stashKey = stageName.replaceAll(' ', '_')
                def stashKeyIpa = "${stashKey}_IPA"
                def stashKeyZip = "${stashKey}_ZIP"

                // Temporarily stash, for use later in archiving the artifacts or uploading to an artifact server
                stash includes: '**/*.ipa', name: stashKeyIpa
                stash includes: '*.zip', name: stashKeyZip

                stashes.push(stashKeyIpa)
                stashes.push(stashKeyZip)
            }
        }
    }
}

// Build In Parallel (Parallel is optional)
// Master node here only related to in house set up, feel free to use anything here to trigger jobs and artifacts
node('master') {
    checkout scm

    jenkinsJobs = [:]

    jenkinsJobs.put('Test', { test('Test', xcodeTestScheme) })

    jenkinsJobs.put('Build', {
        build(
                'Build',
                'L4_Enterprise_Keychain',
                'L4_ENTERPRISE_KEYCHAIN_PASSWORD',
                'In_House',
                'L4_ENTERPRISE_KEYCHAIN_IDENTITY',
                l4Plist,
                'JENKINS_ADVENTURES_IN_HOUSE'
        )
    })

    parallel(jenkinsJobs)

    // Unstash all build artifacts
    for (stash in stashes) {
        unstash stash
    }

    archiveArtifacts '**/*.zip, **/*.ipa, build/reports/*.xml'
}

