
START "" /B /D "VisualStudio\adanaxis-win64deps" /WAIT powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile -File build.ps1 "%BUILD_CONFIGURATION%" "%TRAVIS_BUILD_NUMBER%" -InstallMissing
EXIT /B %ERRORLEVEL%
