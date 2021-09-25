Param (
    [Parameter (Mandatory = $false, Position = 1)]
    [string]$FilesDir,

    [Parameter (Mandatory = $false, Position = 2)]
    [string]$DownloadDir
)

Write-Host $FilesDir

if ($FilesDir -eq "") {
    $FilesDir = ".\"
}
elseif (!$FilesDir.EndsWith('\')) {
    $FilesDir += '\'
}

if ($DownloadDir -eq "") {
    $DownloadDir = "UUPs\"
}
elseif (!$DownloadDir.EndsWith('\')) {
    $DownloadDir += '\'
}

$infiles = @(
    [PSCustomObject]@{ Filename = "$($FilesDir)links.txt"; Exists = 'No' },
    [PSCustomObject]@{ Filename = "$($FilesDir)rename.bat"; Exists = 'No' },
    [PSCustomObject]@{ Filename = "$($FilesDir)crc.sha1"; Exists = 'No' }
)

Write-Host -ForegroundColor Cyan "`nChecking required files..."

$infiles | ForEach-Object -Process {
    Write-Host $_.Filename "`t: " -NoNewline
    $result = Test-Path $_.Filename
    If ($result -eq "True") {
        $_.Exists = "Yes"
        Write-Host -ForegroundColor Green "present"
    }
    else {
        Write-Host -ForegroundColor Red "absent!"
    }
}

# $infiles | Format-Table -HideTableHeaders -AutoSize

$infiles.Exists | ForEach-Object -Process {
    If ($_ -ne "Yes") {
        Write-Host -ForegroundColor Red "One or several files are absent!`nScript execution was aborted.`n"
        Write-Host -ForegroundColor Cyan "`nPress any key to exit..."
        [void] $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
        Exit
    }
}

Write-Host -ForegroundColor Cyan "`nAll required files are in place, starting download with proper filenames by the list...`n"

$urls = Get-Content -Path $infiles.Filename[0]
$bats = Get-Content -Path $infiles.Filename[1]
$sha1s = Get-Content -Path $infiles.Filename[2]
$count = $urls.Count

$offset = 0
if ($bats[0] -eq "@echo off") {
    $offset = 1
}

$uuids = [string[]]::New($count)
$filenames = [string[]]::New($count)
$hashes = [string[]]::New($count)

for ($i = 0; $i -lt $count; $i++) {
    $str = $urls[$i] -match "[0-9a-f]{8}\b-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-\b[0-9a-f]{12}"
    $uuids[$i] = $Matches.0
    for ($j = 0; $j -lt $count; $j++) {
        $str = $bats[$j + $offset].Replace("`"", "").Split(" ")
        if ($str[1] -eq $uuids[$i]) {
            $filenames[$i] = $str[2]
        }
    }
    for ($j = 0; $j -lt $count; $j++) {
        $str = $sha1s[$j].Replace("*", "").Split(" ")
        if ($str[1] -eq $filenames[$i]) {
            $hashes[$i] = $str[0]
        }
    }
}

$result = New-Item -Path $DownloadDir -ItemType Directory -Force

$ProgressPreference = 'SilentlyContinue'
$countstr = $count.ToString()
$countstrlen = $countstr.Length

for ($i = 0; $i -lt $count; $i++) {
    $FilenameWidth = $Host.UI.RawUI.WindowSize.Width - 38
    $filename = $DownloadDir + $filenames[$i]
    $showfilename = $filename
    if ($filename.Length -gt $FilenameWidth) {
        $showfilename = $filename.Substring(0, $FilenameWidth / 2) + "…" + $filename.Substring($filename.Length - $FilenameWidth / 2 + 1, $FilenameWidth / 2)
    }
    $istr = ($i + 1).ToString().PadLeft($countstrlen, "0")
    Write-Host -ForegroundColor Cyan "[$istr/$countstr]"
    Write-Host "Downloading file: `"" -NoNewline
    Write-Host -ForegroundColor Yellow $showfilename -NoNewline
    Write-Host "`"`t: " -NoNewLine
    try {
        Invoke-WebRequest $urls[$i] -Outfile $filename
    }
    catch {
        $catcherror = $_.Exception.Response.StatusCode.value__
        Write-Host -ForegroundColor Red "Error $catcherror"
        if ($error -eq 403) {
            $infiles | ForEach-Object {
                Remove-Item -Path $_.Filename
            }
        }
        Write-Host -ForegroundColor Cyan "Filelists were deleted as outdated."
        Write-Host -ForegroundColor Cyan "`nPress any key to exit..."
        [void] $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
        Exit
    }
    Write-Host -ForegroundColor Green "OK"
    Write-Host "Checking hash for `"" -NoNewline
    Write-Host -ForegroundColor Yellow $showfilename -NoNewline
    Write-Host "`"`t: " -NoNewLine
    If ($hashes[$i] -eq (Get-FileHash $filename -Algorithm SHA1).Hash) {
        Write-Host -ForegroundColor Green "OK`n"
    }
    else {
        Write-Host -ForegroundColor Red "Do not match!"
        Write-Host -ForegroundColor Red "At least one hash didn't match. Remain operations are canceled."
        Write-Host -ForegroundColor Cyan "`nPress any key to exit..."
        [void] $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
        Exit
    }
}
$ProgressPreference = 'Continue'

Write-Host -ForegroundColor Cyan "Deleting no more needed filelists... " -NoNewline

$infiles | ForEach-Object {
    Remove-Item -Path $_.Filename
}

Write-Host -ForegroundColor Green "Done"
Write-Host -ForegroundColor Cyan "`nPress any key to exit..."
[void] $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
#>