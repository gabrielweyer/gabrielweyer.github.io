[CmdletBinding()]
Param(
    [switch]$DeployOnGitHub
)

$ErrorActionPreference = "Stop"

$tmpPath = [io.path]::combine([System.IO.Path]::GetTempPath(), "jekyll-$([System.Guid]::NewGuid())")

Write-Verbose "Deployment path is: $tmpPath"

docker run `
    --rm `
    --volume="$($PWD):/srv/jekyll" `
    --volume="$($tmpPath):/publish" `
    --workdir="/srv/jekyll" `
    -it `
    jekyll/jekyll:3.6.2 `
    jekyll build --destination /publish

if ($LASTEXITCODE -ne 0) {
    throw 'Error when building the Jekyll site in Docker'
}

Write-Output "Deployed static site to: $tmpPath"

if (!($DeployOnGitHub)) {
    Write-Output 'Skipping deploy on GitHub'
    Exit;
}

try {
    git checkout master
    git pull --rebase origin master

    Copy-Item "$($tmpPath)/*" $PWD -Recurse

    git add .

    git commit -m "Release"
    git push origin master
}
finally {
    Remove-Item -Recurse $tmpPath
}
