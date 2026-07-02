# Impacchetta il contenuto di una cartella "release" Flutter Windows (exe + DLL + data/)
# in un unico exe portabile, usando Enigma Virtual Box (enigmavbconsole.exe).
#
# Enigma Virtual Box va installato una tantum (gratuito):
#   https://enigmaprotector.com/en/downloads.html
# Se non e' in una delle cartelle standard, imposta la variabile d'ambiente ENIGMA_VB_PATH
# con il percorso completo di enigmavbconsole.exe.

param(
    [Parameter(Mandatory = $true)][string]$ReleaseDir,
    [Parameter(Mandatory = $true)][string]$OutputExe
)

$ErrorActionPreference = "Stop"

function Find-EnigmaConsole {
    if ($env:ENIGMA_VB_PATH -and (Test-Path $env:ENIGMA_VB_PATH)) {
        return $env:ENIGMA_VB_PATH
    }
    $candidates = @(
        "$env:ProgramFiles\Enigma Virtual Box\enigmavbconsole.exe",
        "${env:ProgramFiles(x86)}\Enigma Virtual Box\enigmavbconsole.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $cmd = Get-Command enigmavbconsole.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Xml-Escape([string]$s) {
    return $s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
}

# Costruisce ricorsivamente il nodo <Files> del progetto .evb per il contenuto di una cartella
function Build-FilesXml([string]$dir) {
    $sb = New-Object System.Text.StringBuilder
    Get-ChildItem -LiteralPath $dir | Sort-Object Name | ForEach-Object {
        $name = Xml-Escape $_.Name
        if ($_.PSIsContainer) {
            $sb.AppendLine("<File><Type>3</Type><Name>$name</Name><Action>0</Action><OverwriteDateTime>false</OverwriteDateTime><OverwriteAttributes>false</OverwriteAttributes><Files>") | Out-Null
            $sb.Append((Build-FilesXml $_.FullName)) | Out-Null
            $sb.AppendLine("</Files></File>") | Out-Null
        }
        else {
            $fullPath = Xml-Escape $_.FullName
            $sb.AppendLine("<File><Type>2</Type><Name>$name</Name><File>$fullPath</File><ActiveX>false</ActiveX><ActiveXInstall>false</ActiveXInstall><Action>0</Action><OverwriteDateTime>false</OverwriteDateTime><OverwriteAttributes>false</OverwriteAttributes><PassCommandLine>false</PassCommandLine></File>") | Out-Null
        }
    }
    return $sb.ToString()
}

$enigma = Find-EnigmaConsole
if (-not $enigma) {
    Write-Warning "Enigma Virtual Box non trovato. Installalo da https://enigmaprotector.com/en/downloads.html (gratuito), oppure imposta ENIGMA_VB_PATH con il percorso di enigmavbconsole.exe."
    exit 1
}

if (-not (Test-Path $ReleaseDir)) { throw "Cartella release non trovata: $ReleaseDir" }

$mainExe = Get-ChildItem -LiteralPath $ReleaseDir -Filter *.exe | Select-Object -First 1
if (-not $mainExe) { throw "Nessun .exe trovato in $ReleaseDir" }

$outDir = Split-Path $OutputExe -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$entriesXml = Get-ChildItem -LiteralPath $ReleaseDir | Where-Object { $_.FullName -ne $mainExe.FullName } | Sort-Object Name | ForEach-Object {
    if ($_.PSIsContainer) {
        $name = Xml-Escape $_.Name
        "<File><Type>3</Type><Name>$name</Name><Action>0</Action><OverwriteDateTime>false</OverwriteDateTime><OverwriteAttributes>false</OverwriteAttributes><Files>" + (Build-FilesXml $_.FullName) + "</Files></File>"
    }
    else {
        $name = Xml-Escape $_.Name
        $fullPath = Xml-Escape $_.FullName
        "<File><Type>2</Type><Name>$name</Name><File>$fullPath</File><ActiveX>false</ActiveX><ActiveXInstall>false</ActiveXInstall><Action>0</Action><OverwriteDateTime>false</OverwriteDateTime><OverwriteAttributes>false</OverwriteAttributes><PassCommandLine>false</PassCommandLine></File>"
    }
}
$entriesXmlJoined = ($entriesXml -join "`r`n")

$projectXml = @"
<?xml encoding="utf-16"?>
<>
	<InputFile>$(Xml-Escape $mainExe.FullName)</InputFile>
	<OutputFile>$(Xml-Escape $OutputExe)</OutputFile>
	<Files>
		<Enabled>true</Enabled>
		<DeleteExtractedOnExit>true</DeleteExtractedOnExit>
		<CompressFiles>true</CompressFiles>
		<Files>
			<File>
				<Type>3</Type>
				<Name>%DEFAULT FOLDER%</Name>
				<Action>0</Action>
				<OverwriteDateTime>false</OverwriteDateTime>
				<OverwriteAttributes>false</OverwriteAttributes>
				<Files>
$entriesXmlJoined
				</Files>
			</File>
		</Files>
	</Files>
	<Registries>
		<Enabled>false</Enabled>
		<Registries>
			<Registry><Type>1</Type><Virtual>true</Virtual><Name>Classes</Name><ValueType>0</ValueType><Value/><Registries/></Registry>
			<Registry><Type>1</Type><Virtual>true</Virtual><Name>User</Name><ValueType>0</ValueType><Value/><Registries/></Registry>
			<Registry><Type>1</Type><Virtual>true</Virtual><Name>Machine</Name><ValueType>0</ValueType><Value/><Registries/></Registry>
			<Registry><Type>1</Type><Virtual>true</Virtual><Name>Users</Name><ValueType>0</ValueType><Value/><Registries/></Registry>
			<Registry><Type>1</Type><Virtual>true</Virtual><Name>Config</Name><ValueType>0</ValueType><Value/><Registries/></Registry>
		</Registries>
	</Registries>
	<Packaging>
		<Enabled>false</Enabled>
	</Packaging>
	<Options>
		<ShareVirtualSystem>true</ShareVirtualSystem>
		<MapExecutableWithTemporaryFile>false</MapExecutableWithTemporaryFile>
		<AllowRunningOfVirtualExeFiles>false</AllowRunningOfVirtualExeFiles>
	</Options>
</>
"@

$projectFile = Join-Path $env:TEMP "pack_portable_exe.evb"
Set-Content -LiteralPath $projectFile -Value $projectXml -Encoding Unicode

Write-Host "Packaging con Enigma Virtual Box -> $OutputExe" -ForegroundColor Cyan
& $enigma $projectFile
if ($LASTEXITCODE -ne 0) { throw "enigmavbconsole ha restituito codice $LASTEXITCODE" }

Write-Host "Fatto: $OutputExe" -ForegroundColor Green
