# bump_version.ps1 — Incrementa patch number y versionCode en pubspec.yaml

$pubspec = "pubspec.yaml"
$content = Get-Content $pubspec -Raw

if ($content -match 'version:\s+(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $build = [int]$Matches[4]

    $newPatch = $patch + 1
    $newBuild = $build + 1

    $oldVersion = "$major.$minor.$patch+$build"
    $newVersion = "$major.$minor.$newPatch+$newBuild"

    $content = $content -replace "version:\s+$major\.$minor\.$patch\+$build", "version: $newVersion"
    Set-Content $pubspec $content -NoNewline

    Write-Host "Version bumped: $oldVersion -> $newVersion"
} else {
    Write-Error "Could not parse version from pubspec.yaml"
    exit 1
}
