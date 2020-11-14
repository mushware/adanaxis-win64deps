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
$AdanaxisBuildRoot = $(Join-Path -Resolve $ProjectRoot -ChildPath "VisualStudio\adanaxis-win64deps")
$LibzlibRoot = $(Join-Path -Resolve $ProjectRoot -ChildPath "zlib")
$LibzlibBuildRoot = $(Join-Path $LibzlibRoot -ChildPath "build")
$LibjpegRoot = $(Join-Path -Resolve $ProjectRoot -ChildPath "libjpeg-turbo")
$LibjpegBuildRoot = $(Join-Path $LibjpegRoot -ChildPath "build")
$LibtiffRoot = $(Join-Path -Resolve $ProjectRoot -ChildPath "libtiff")
$LibtiffBuildRoot = $(Join-Path $LibtiffRoot -ChildPath "build")
$LibtiffBuildRootCMakeLists = $(Join-Path $LibtiffBuildRoot -ChildPath "CMakeLists.txt")
Set-Location $AdanaxisBuildRoot

$cmake_root="C:\Program Files\CMake\bin"
$msbuild_root="C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin"
$signtool_root="C:\Program Files (x86)\Windows Kits\10\bin\10.0.18362.0\x86"

$env:PATH = "$msbuild_root;$signtool_root;$cmake_root;$env:PATH"

Write-Host "Path for build is:"
Get-ChildItem env:PATH | ForEach-Object { $_.Value.Split(';') }

If ($null -eq (Get-Command -ErrorAction SilentlyContinue cmake)) {
    Throw "CMake not installed, use e.g. choco install --yes cmake.install --version 3.16.2"
}

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
$libtiff_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "-G", "`"Visual Studio 15 2017 Win64`"", "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON", "-DJPEG_LIBRARY:PATH=$LibjpegBuildRoot\$Configuration\jpeg-static.lib", "-DJPEG_INCLUDE_DIR:PATH=$LibjpegRoot", "-DZLIB_LIBRARY:PATH=$LibzlibLibPath", "-DZLIB_INCLUDE_DIR:PATH=$LibzlibRoot", ".."
$handle = $libtiff_cmake_process.Handle # Fix for missing ExitCode
$libtiff_cmake_process.WaitForExit()

if ($libtiff_cmake_process.ExitCode -ne 0) {
    throw "Libtiff CMake failed ($($libtiff_cmake_process.ExitCode))"
}

Write-Host -ForegroundColor DarkCyan @"

Executing CMake to build.

"@

$libtiff_cmake_process = Start-Process -NoNewWindow -PassThru -FilePath "cmake.exe" -ArgumentList "--build", ".", "--config", "$Configuration", "--parallel"
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

Write-Host -ForegroundColor Green @"

**************************
*                        *
*    BUILD SUCCESSFUL    *
*                        *
**************************

"@

Write-Host -ForegroundColor Blue "$Configuration build complete for Adanaxis win64Deps version $Version"
