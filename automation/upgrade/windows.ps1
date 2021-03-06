$scriptName = 'cdafUpgrade.ps1'
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($env:http_proxy) {
    Write-Host "[$scriptName] `$env:http_proxy : $env:http_proxy`n"
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$env:http_proxy')"
} else {
    Write-Host "[$scriptName] `$env:http_proxy : (not set)`n"
}

$zipFile = 'LU-CDAF.zip'
$url = "http://cdaf.io/static/app/downloads/$zipFile"
$extract = "$env:TEMP\LU-CDAF"
if (Test-Path $extract ) {
	executeExpression "Remove-Item -Recurse -Force $extract"
}
executeExpression "mkdir $extract"
executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$extract\$zipfile')"
executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$extract\$zipfile', '$extract')"
 
executeExpression 'Remove-Item -Recurse .\automation\'
executeExpression 'Copy-Item -Recurse $extract\automation .'

git branch
if ( $LASTEXITCODE -eq 0 ) {
	executeExpression 'cd automation'
	executeExpression 'foreach ($file in Get-ChildItem) {git add $file}'
	executeExpression 'foreach ($script in Get-ChildItem -Recurse *.sh) {git add $script; git update-index --chmod=+x $script}'
	executeExpression 'cd ..'
} else {
	svn ls
	if ( $LASTEXITCODE -eq 0 ) {
		executeExpression 'foreach ($file in Get-ChildItem) {svn add $file --force}'
		executeExpression 'foreach ($script in Get-ChildItem -Recurse *.sh) {svn propset svn:executable ON $script}'
	} else {
		cmd /c "exit 0"
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
