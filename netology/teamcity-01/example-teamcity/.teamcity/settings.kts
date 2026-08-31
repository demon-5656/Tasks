import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.maven
import jetbrains.buildServer.configs.kotlin.triggers.vcs

version = "2022.04"

project {
    buildType(BuildPlainDoll)
}

object BuildPlainDoll : BuildType({
    name = "Build PlainDoll"

    artifactRules = "target/*.jar => target"

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        maven {
            name = "Test non-master branches"
            conditions {
                doesNotContain("teamcity.build.branch", "master")
            }
            goals = "clean test"
        }
        maven {
            name = "Deploy master"
            conditions {
                contains("teamcity.build.branch", "master")
            }
            goals = "clean deploy"
            userSettingsSelection = "settings.xml"
        }
    }

    triggers {
        vcs {
        }
    }
})
