#%Header {
##############################################################################
#
# File VisualStudio/adanaxis/build.ps1
#
# Copyright: Andy Southgate 2002-2007, 2020
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
##############################################################################
#%Header } Qr5Vw09MMnMYlaXKb6VQrA

Param(
    [Parameter(Mandatory)]$Configuration,
    [Parameter(Mandatory)]$BuildNumber,
    [Parameter(Mandatory=$false)][Switch]$InstallMissing
)

Set-StrictMode -Version 3.0

$ErrorActionPreference = "Stop"

$LibpcreName = "pcre-8.44"
$LibpcreZipName = "$LibpcreName.zip"
$LibpcreUrl = "https://ftp.pcre.org/pub/pcre/$LibpcreZipName"

If ($BuildNumber) {
    If ($BuildNumber -as [int] -gt 65534) {
        Throw "Build number too large"
    }
    $Version = "0.1.0.$BuildNumber"
    If ($env:TRAVIS_TAG) {
        If ($env:TRAVIS_TAG -match "^v\d+\.\d+\.\d+$") {
            $Version = "$($env:TRAVIS_TAG.Substring(1)).$BuildNumber"
        } Else {
            Write-Error "Badly formed or non-release git tag ""$($env:TRAVIS_TAG)"""
        }
    } else {
    }
} Else {
    $Version = "0.0.0.0"
}

Write-Host -ForegroundColor Blue @"
*
*
* Beginning Adanaxis win64deps $Configuration build for version $Version.
*
*
"@

Write-Host "Path is:"
Get-ChildItem env:PATH | ForEach-Object { $_.Value.Split(';') }

If ($Configuration -eq "") {
    Write-Host "Configuration not supplied so using Debug"
    $Configuration = "Debug"
}

if ($PSScriptRoot) {
    $ProjectRoot = $(Join-Path -Resolve $PSScriptRoot -ChildPath "..\..")
} Else {
    $ProjectRoot = $(Join-Path -Resolve $pwd -ChildPath "..\..")
}

$underscore_version = $Version.Replace(".", "_")

$AdanaxisBuildRoot = $(Join-Path -Resolve $ProjectRoot -ChildPath "VisualStudio\adanaxis-win64deps")
$AdanaxisOutRoot = $(Join-Path $ProjectRoot -ChildPath "out")
$AdanaxisOutName = "adanaxis-win64deps-$Configuration-$underscore_version.zip"
$AdanaxisOutPath = $(Join-Path $ProjectRoot -ChildPath $AdanaxisOutName)
$AdanaxisManifestPath = $(Join-Path $AdanaxisOutRoot -ChildPath "manifest.ps1")
$AdanaxisTagName = "tagfile_${Configuration}_${underscore_version}.txt"
$AdanaxisTagPath = $(Join-Path $AdanaxisOutRoot -ChildPath $AdanaxisTagName)
$AdanaxisVersionName = "manifest.json"
$AdanaxisVersionPath = $(Join-Path $AdanaxisOutRoot -ChildPath $AdanaxisVersionName)

$LibpcreRoot = $(Join-Path $ProjectRoot -ChildPath "libpcre")
$LibpcreBuildRoot = $(Join-Path $LibpcreRoot -ChildPath $LibpcreName)
$LibpcreTagPath = $(Join-Path $LibpcreBuildRoot -ChildPath "CMakeLists.txt")
$LibpcreZipPath = $(Join-Path $LibpcreRoot -ChildPath $LibpcreZipName)
$LibzlibRoot = $(Join-Path -Resolve $ProjectRoot -ChildPath "zlib")
$LibzlibBuildRoot = $(Join-Path $LibzlibRoot -ChildPath "build")
$LibexpatRoot = $(Join-Path $ProjectRoot -ChildPath "libexpat")
$LibexpatBuildRoot = $(Join-Path $LibexpatRoot -ChildPath "expat")
$LibjpegRoot = $(Join-Path -Resolve $ProjectRoot -ChildPath "libjpeg-turbo")
$LibjpegBuildRoot = $(Join-Path $LibjpegRoot -ChildPath "build")
$LibtiffRoot = $(Join-Path -Resolve $ProjectRoot -ChildPath "libtiff")
$LibtiffBuildRoot = $(Join-Path $LibtiffRoot -ChildPath "build")
$LibtiffBuildRootCMakeLists = $(Join-Path $LibtiffBuildRoot -ChildPath "CMakeLists.txt")
Set-Location $AdanaxisBuildRoot

$cmake_root="C:\Program Files\CMake\bin"
$msbuild_root="C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin"
$nasm_root="C:\Program Files\NASM"
$signtool_root="C:\Program Files (x86)\Windows Kits\10\bin\10.0.18362.0\x86"

$env:PATH = "$msbuild_root;$nasm_root;$signtool_root;$cmake_root;$env:PATH"

Write-Host "Path for build is:"
Get-ChildItem env:PATH | ForEach-Object { $_.Value.Split(';') }

If (Test-Path $nasm_root) {
    Write-Host "NASM already installed."
    $nasm_job = Start-Job -ScriptBlock { Write-Output "(output from null install job) NASM already installed" }
} Else {
    If ($InstallMissing) {
        Write-Host "Launching job to install NASM."
        $nasm_job = Start-Job -File "./install_nasm.ps1"
    } Else {
        Throw "NASM not found but cannot install, please install or supply -InstallMissing as a parameter."
    }
}

Receive-Job -Job $nasm_job -Wait

If ($null -eq (Get-Command -ErrorAction SilentlyContinue cmake)) {
    Throw "CMake not installed, use e.g. choco install --yes cmake.install --version 3.16.2"
}

If ($null -eq (Get-Command -ErrorAction SilentlyContinue nasm)) {
    Throw "NASM not installed, use e.g. choco install --yes nasm --version 2.14.02"
}

New-Item -ItemType "directory" -Path $AdanaxisOutRoot -Force | Foreach-Object { "Created directory $($_.FullName)" }

Write-Host -ForegroundColor DarkCyan @"

*********************************************************************
*                                                                   *
*    Building zlib library                                          *
*    Props to https://github.com/madler/zlib.git                    *
*                                                                   *
*********************************************************************

"@

New-Item -ItemType "directory" -Path $LibzlibBuildRoot -Force | Foreach-Object { "Created directory $($_.FullName)" }
# New-Item -ItemType "file" -Path $LibzlibBuildRootCMakeLists -Force | Foreach-Object { "Created file $($_.FullName)" }

Set-Location $LibzlibBuildRoot

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to configure.

"@

$libzlib_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "-G", "`"Visual Studio 15 2017 Win64`"", ".."
$handle = $libzlib_cmake_process.Handle # Fix for missing ExitCode
$libzlib_cmake_process.WaitForExit()

if ($libzlib_cmake_process.ExitCode -ne 0) {
    throw "Libzlib CMake failed ($($libzlib_cmake_process.ExitCode))"
}

if ($Configuration -eq "Debug") {
    $LibzlibLibPath = "$LibzlibBuildRoot\$Configuration\zlibd.lib"
} else {
    $LibzlibLibPath = "$LibzlibBuildRoot\$Configuration\zlib.lib"
}

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to build.

"@

$libzlib_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "--build", ".", "--config", "$Configuration", "--parallel"
$handle = $libzlib_cmake_process.Handle # Fix for missing ExitCode
$libzlib_cmake_process.WaitForExit()

if ($libzlib_cmake_process.ExitCode -ne 0) {
    throw "Libzlib CMake failed ($($libzlib_cmake_process.ExitCode))"
}

Write-Host -ForegroundColor DarkCyan @"

*********************************************************************
*                                                                   *
*    Building expat library                                         *
*    Props to https://github.com/libexpat/libexpat.git              *
*                                                                   *
*********************************************************************

"@

New-Item -ItemType "directory" -Path $LibexpatBuildRoot -Force | Foreach-Object { "Created directory $($_.FullName)" }

Set-Location $LibexpatBuildRoot

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to configure.

"@

$libexpat_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "-G", "`"Visual Studio 15 2017 Win64`"", "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON", "-DCMAKE_INSTALL_PREFIX=$AdanaxisOutRoot", "-DEXPAT_SHARED_LIBS:BOOL=OFF", "."
$handle = $libexpat_cmake_process.Handle # Fix for missing ExitCode
$libexpat_cmake_process.WaitForExit()

if ($libexpat_cmake_process.ExitCode -ne 0) {
    throw "Libexpat CMake failed ($($libexpat_cmake_process.ExitCode))"
}

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to build.

"@

$libexpat_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "--build", ".", "--config", "$Configuration", "--parallel", "--target", "install"
$handle = $libexpat_cmake_process.Handle # Fix for missing ExitCode
$libexpat_cmake_process.WaitForExit()

if ($libexpat_cmake_process.ExitCode -ne 0) {
    throw "Libexpat CMake failed ($($libexpat_cmake_process.ExitCode))"
}

Write-Host -ForegroundColor DarkCyan @"

*********************************************************************
*                                                                   *
*    Building libjpeg-turbo library                                 *
*    Props to https://github.com/libjpeg-turbo/libjpeg-turbo.git    *
*                                                                   *
*********************************************************************

"@

New-Item -ItemType "directory" -Path $LibjpegBuildRoot -Force | Foreach-Object { "Created directory $($_.FullName)" }
# New-Item -ItemType "file" -Path $LibjpegBuildRootCMakeLists -Force | Foreach-Object { "Created file $($_.FullName)" }

Set-Location $LibjpegBuildRoot

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to configure.

"@
$libjpeg_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "-G", "`"Visual Studio 15 2017 Win64`"", ".."
$handle = $libjpeg_cmake_process.Handle # Fix for missing ExitCode
$libjpeg_cmake_process.WaitForExit()

if ($libjpeg_cmake_process.ExitCode -ne 0) {
    throw "Libjpeg CMake failed ($($libjpeg_cmake_process.ExitCode))"
}

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to build.

"@

$libjpeg_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "--build", ".", "--config", "$Configuration", "--parallel"
$handle = $libjpeg_cmake_process.Handle # Fix for missing ExitCode
$libjpeg_cmake_process.WaitForExit()

if ($libjpeg_cmake_process.ExitCode -ne 0) {
    throw "Libjpeg CMake failed ($($libjpeg_cmake_process.ExitCode))"
}


Write-Host -ForegroundColor DarkCyan @"

*********************************************************
*                                                       *
*    Building libtiff library                           *
*    Props to https://gitlab.com/libtiff/libtiff.git    *
*                                                       *
*********************************************************

"@

New-Item -ItemType "directory" -Path $LibtiffBuildRoot -Force | Foreach-Object { "Created directory $($_.FullName)" }
New-Item -ItemType "file" -Path $LibtiffBuildRootCMakeLists -Force | Foreach-Object { "Created file $($_.FullName)" }

Set-Location $LibtiffBuildRoot

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to configure.

"@

$env:CFLAGS="/I`"$LibzlibBuildRoot`" /I`"$LibjpegBuildRoot`""
$libtiff_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "-G", "`"Visual Studio 15 2017 Win64`"", "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON", "-DCMAKE_INSTALL_PREFIX=$AdanaxisOutRoot", "-DJPEG_LIBRARY:PATH=$LibjpegBuildRoot\$Configuration\jpeg-static.lib", "-DJPEG_INCLUDE_DIR:PATH=$LibjpegRoot", "-DZLIB_LIBRARY:PATH=$LibzlibLibPath", "-DZLIB_INCLUDE_DIR:PATH=$LibzlibRoot", ".."
$handle = $libtiff_cmake_process.Handle # Fix for missing ExitCode
$libtiff_cmake_process.WaitForExit()

if ($libtiff_cmake_process.ExitCode -ne 0) {
    throw "Libtiff CMake failed ($($libtiff_cmake_process.ExitCode))"
}

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to build.

"@

$libtiff_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "--build", ".", "--config", "$Configuration", "--parallel", "--target", "install"
$handle = $libtiff_cmake_process.Handle # Fix for missing ExitCode
$libtiff_cmake_process.WaitForExit()

if ($libtiff_cmake_process.ExitCode -ne 0) {
    throw "Libtiff CMake failed ($($libtiff_cmake_process.ExitCode))"
}

Set-Location $LibtiffRoot

# $libtiff_build_process = Start-Process -NoNewWindow -PassThru -FilePath "MSBuild.exe" -ArgumentList "build\libtiff.sln", "-maxCpuCount", "-nodeReuse:false", "-target:libtiff", "-property:UseSharedCompilation=false"
# $handle = $libtiff_build_process.Handle # Fix for missing ExitCode
# $libtiff_build_process.WaitForExit()

# if ($libtiff_build_process.ExitCode -ne 0) {
#     throw "Libtiff make failed ($($libtiff_build_process.ExitCode))"
# }


Write-Host -ForegroundColor DarkCyan @"

*********************************************************************
*                                                                   *
*    Building pcre library                                          *
*    Props to https://www.pcre.org/                                 *
*                                                                   *
*********************************************************************

"@

New-Item -ItemType "directory" -Path $LibpcreRoot -Force | Foreach-Object { "Created directory $($_.FullName)" }

Set-Location $LibpcreRoot

if (Test-Path $LibpcreZipPath) {
    Write-Host -ForegroundColor Green @"

File ${LibpcreZipPath} already present in ${LibpcreRoot} so not downloading.

"@
} else {
    Write-Host  -ForegroundColor Blue @"

Fetching ${LibpcreZipName}
to ${LibpcreZipPath}
from ${libpcreUrl}

"@
    Invoke-WebRequest -Uri $LibpcreUrl -OutFile $LibpcreZipPath
}

if (Test-Path $LibpcreTagPath) {
    Write-Host "Removing previous Libpcre directory ${LibpcreBuildRoot}"
    Remove-Item -Path $LibpcreBuildRoot -Recurse
}

Expand-Archive $LibpcreZipPath -DestinationPath $LibpcreRoot

Set-Location $LibpcreBuildRoot

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to configure.

"@
$libpcre_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "-G", "`"Visual Studio 15 2017 Win64`"", "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON", "-DCMAKE_INSTALL_PREFIX=$AdanaxisOutRoot", "."
$handle = $libpcre_cmake_process.Handle # Fix for missing ExitCode
$libpcre_cmake_process.WaitForExit()

if ($libpcre_cmake_process.ExitCode -ne 0) {
    throw "Libpcre CMake failed ($($libpcre_cmake_process.ExitCode))"
}

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to build.

"@

$libpcre_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "--build", ".", "--config", "$Configuration", "--parallel", "--target", "install"
$handle = $libpcre_cmake_process.Handle # Fix for missing ExitCode
$libpcre_cmake_process.WaitForExit()

if ($libpcre_cmake_process.ExitCode -ne 0) {
    throw "Libpcre CMake failed ($($libpcre_cmake_process.ExitCode))"
}


Write-Host -ForegroundColor DarkCyan @"

Writing file manifest to $AdanaxisManifestPath.

"@

Set-Location $AdanaxisOutRoot

Get-Date -UFormat "%A %B/%d/%Y %T %Z"
$time = Get-Date
$time.ToUniversalTime()
$time_str = $time.ToUniversalTime().DateTime
$manifest = [ordered]@{configuration=$Configuration;env=[ordered]@{}; files=[ordered]@{};timestamp=$time_str;version=$Version;}
Get-ChildItem -Recurse -Path "env:TRAVIS*" | Sort-Object FullName | ForEach-Object { $manifest["env"][$_.Name] = $_.Value }
Get-ChildItem -Recurse -Path . | Sort-Object FullName | Get-FileHash -Algorithm SHA256 | ForEach-Object { $manifest["files"][$(Resolve-Path $_.Path -Relative).Substring(2).Replace("\", "/")] = $_.Hash}
$manifest_content = $manifest | ConvertTo-Json

Set-Content -Path $AdanaxisManifestPath @"
$manifest_content
#END

# Signature below is self-signed but the timestamp verifies the time of building.
"@

Set-Content -Path $AdanaxisTagPath "$Configuration $Version ""$time_str"""
Set-Content -Path $AdanaxisVersionPath $manifest_content

Write-Host "User: ${env:UserName}"
Write-Host "TRAVIS: ${env:TRAVIS}"

if ($env:TRAVIS -eq "true") {
    $cert_store = "\LocalMachine\My"
} else {
    $cert_store = "\CurrentUser\My"
}

if (!(Get-ChildItem cert:\CurrentUser\My -CodeSigning | Where-Object { $_.Subject -eq "CN=Local Code Signing" })) {
    New-SelfSignedCertificate -CertStoreLocation Cert:$cert_store `
    -Subject "CN=Local Code Signing" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
    -KeyExportPolicy Exportable `
    -KeyUsage DigitalSignature `
    -Type CodeSigningCert
}

$cert = Get-ChildItem Cert:$cert_store -CodeSigning | Where-Object { $_.Subject -eq "CN=Local Code Signing" }

Set-AuthenticodeSignature -FilePath $AdanaxisManifestPath -Certificate $cert -IncludeChain All -TimestampServer "http://timestamp.comodoca.com/authenticode"

Get-Content $AdanaxisManifestPath | Write-Host -ForegroundColor DarkGray

Write-Host -ForegroundColor DarkCyan @"

Creating output archive $AdanaxisOutName.

"@

If (Test-Path $AdanaxisOutPath) {
    Remove-Item $AdanaxisOutPath
}
Get-ChildItem -Path $AdanaxisOutRoot | Compress-Archive -DestinationPath $AdanaxisOutPath

Write-Host -ForegroundColor Green @"

**************************
*                        *
*    BUILD SUCCESSFUL    *
*                        *
**************************

"@

Write-Host -ForegroundColor Blue "$Configuration build complete for Adanaxis win64Deps version $Version"
$archive_hash = (Get-FileHash -Algorithm SHA256 $AdanaxisOutPath).Hash
Write-Host -ForegroundColor DarkGray "$AdanaxisOutName SHA256 is $archive_hash"
