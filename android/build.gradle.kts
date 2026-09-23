// Este archivo es el build script de RAÍZ del proyecto Android (distinto de
// android/app/build.gradle.kts, que es el del módulo :app). En algún punto
// quedó reemplazado por una copia completa de android/app/build.gradle.kts
// (mismo "plugins { id(\"com.android.application\") }" + bloque "android {}"
// con namespace/defaultConfig/etc. + "kotlin { compilerOptions {...} }") —
// eso no compila acá: la raíz del proyecto no tiene aplicado el plugin de
// Kotlin de la misma forma que :app, así que "compilerOptions"/"jvmTarget"
// no existen en este contexto ("Unresolved reference"), y aplicar
// com.android.application en la raíz es inválido de por sí. Se restaura el
// contenido original (solo repos compartidos + redirección de build dir),
// que es lo único que le corresponde a este archivo.
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
