import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.triggers.vcs

version = "2022.04"

project {
    buildType(BuildPlainDoll)
}

object BuildPlainDoll : BuildType({
    name = "Build PlainDoll"

    artifactRules = "target/*.jar => jars"

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Branch-aware Maven build"
            scriptContent = """
                if [ "%teamcity.build.branch%" = "master" ]; then
                  /opt/buildagent/tools/maven3_6/bin/mvn -s /opt/buildagent/conf/settings.xml clean deploy
                else
                  /opt/buildagent/tools/maven3_6/bin/mvn clean test
                fi
            """.trimIndent()
        }
    }

    triggers {
        vcs {
        }
    }
})
