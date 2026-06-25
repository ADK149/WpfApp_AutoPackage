@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%config.json"

set "TARGET_VERSION="
echo Please enter target version:
set /p "TARGET_VERSION=Target Version: "
if not defined TARGET_VERSION (
  echo Target version cannot be empty.
  goto :end
)

call :ReadConfig
  if errorlevel 1 goto :end

call :ChangeBranch
  if errorlevel 1 goto :end

call :PullBranch
  if errorlevel 1 goto :end

call :BuildPackage
  if errorlevel 1 goto :end

call :MakeTag
  if errorlevel 1 goto :end

call :UploadPackage
  if errorlevel 1 goto :end

goto :end

:ReadConfig
  echo Reading %CONFIG_FILE%...
  powershell -NoProfile -Command "Get-Content -Raw '%CONFIG_FILE%'"

  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json | Select-Object -ExpandProperty target_branch"`) do set "TARGET_BRANCH=%%A"
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json | Select-Object -ExpandProperty configuration"`) do set "CONFIGURATION=%%A"
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json | Select-Object -ExpandProperty proj_path"`) do set "PROJ_PATH=%%A" 
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json | Select-Object -ExpandProperty msbuild_path"`) do set "MSBUILD_PATH=%%A"
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json | Select-Object -ExpandProperty nuget_source"`) do set "NUGET_SOURCE=%%A"

  for %%I in ("%PROJ_PATH%") do set "REPO_PATH=%%~dpI"
  set "NUGET_DIR=%REPO_PATH%bin\%CONFIGURATION%" 

  echo target_branch=%TARGET_BRANCH%
  echo configuration=%CONFIGURATION%
  echo target_version=%TARGET_VERSION%  
  echo msbuild_path=%MSBUILD_PATH%
  echo nuget_source=%NUGET_SOURCE%
  echo csproj_path=%PROJ_PATH%

  echo repo_path=%REPO_PATH%  
  echo nuget_dir=%NUGET_DIR%

  echo.

  echo Checking .git at "%REPO_PATH%\"
  if not exist "%REPO_PATH%" (
    echo .git not found in "%REPO_PATH%\"
    exit /b 1
  )

  echo Checking MSBuild.exe in "%MSBUILD_PATH%\"
  if not exist "%MSBUILD_PATH%\MSBuild.exe" (
    echo MSBuild.exe not found in "%MSBUILD_PATH%\"
    exit /b 1
  )

    echo Checking .csproj: "%PROJ_PATH%\"
  if not exist "%PROJ_PATH%" (
    echo not found: "%PROJ_PATH%\"
    exit /b 1
  )
  echo.

exit /b 0

:ChangeBranch
  echo ChangeBranch to !TARGET_BRANCH!...
  
  pushd "%REPO_PATH%" || exit /b 1
  set "GIT_DIRTY="
  for /f "delims=" %%I in ('git status --porcelain') do set "GIT_DIRTY=1"
  echo GIT_DIRTY=!GIT_DIRTY!

  for /f "delims=" %%I in ('git rev-parse --abbrev-ref HEAD') do set "CURRENT_BRANCH=%%I"
  echo Current branch: !CURRENT_BRANCH!

  if defined GIT_DIRTY (
    echo Stashing local changes...
    git stash push -u -m "auto-bat-stash" >nul 2>&1
    set "STASHED=1"
  ) else (
    set "STASHED="
  )

  git show-ref --verify --quiet "refs/heads/!TARGET_BRANCH!"
  if errorlevel 1 (
    git show-ref --verify --quiet "refs/remotes/origin/!TARGET_BRANCH!"
    if errorlevel 1 (
      echo Creating new local branch !TARGET_BRANCH!
      git checkout -b !TARGET_BRANCH!
    ) else (
      echo Creating local branch !TARGET_BRANCH! from origin/!TARGET_BRANCH!
      git checkout -b !TARGET_BRANCH! origin/!TARGET_BRANCH!
    )
  ) else (
    echo Switching to existing local branch !TARGET_BRANCH!
    git checkout !TARGET_BRANCH!
  )

  if defined STASHED (
    echo Stash saved, not popped automatically to avoid conflicts.
  )

  for /f "delims=" %%I in ('git rev-parse --abbrev-ref HEAD') do set "CURRENT_BRANCH=%%I"
  echo Current branch: !CURRENT_BRANCH!
  popd
  echo.
exit /b 0

:PullBranch
  echo Updating dev branch...
  
  pushd "%REPO_PATH%" || exit /b 1

  git checkout !TARGET_BRANCH!
  if errorlevel 1 (
    echo Failed to checkout !TARGET_BRANCH! branch
    popd
    exit /b 1
  )

  git pull origin !TARGET_BRANCH!
  if errorlevel 1 (
    echo Failed to pull latest changes from origin/dev
    popd
    exit /b 1
  )
  popd
  echo.
exit /b 0

:BuildPackage
  echo Start BuildPackage...
  
  cd /d "%MSBUILD_PATH%" || exit /b 1
  msbuild %PROJ_PATH% /t:Pack /p:Configuration=%CONFIGURATION% /p:PackageVersion=%TARGET_VERSION%
  if errorlevel 1 (
    echo Failed to update version
    exit /b 1
  )

  echo Version updated successfully
  echo.
exit /b 0

:MakeTag
  echo Start MakeTag...
  
  cd /d "%REPO_PATH%" || exit /b 1
  for /f %%i in ('git rev-parse --short HEAD') do set HASTAG=%%i
  echo Current commit hash: "%HASTAG%"
  pushd "%REPO_PATH%" || exit /b 1
  set "TAGINFO=%CONFIGURATION%_v%TARGET_VERSION%_%HASTAG%"
  echo Creating tag: %TAGINFO%...
  git tag -a "%TAGINFO%" -m "AutoPackageTool MakeTag"
  if errorlevel 1 (
    echo Failed to create tag %TAGINFO%
    popd
    exit /b 1
  )

  git push origin "%TAGINFO%"
  if errorlevel 1 (
    echo Failed to push tag %TAGINFO% to origin
    popd
    exit /b 1
  )  
  popd
  
  echo.
exit /b 0

:UploadPackage
  echo Start UploadPackage...
  
  for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "Get-ChildItem '%NUGET_DIR%\*.nupkg' | Sort-Object Name -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName"`) do set "LATEST_NUPKG=%%F"
  if defined LATEST_NUPKG (
      dotnet nuget push "%LATEST_NUPKG%" -s "%NUGET_SOURCE%" --skip-duplicate
  ) else (
      echo No .nupkg files found in %NUGET_DIR%
  )
  
  echo.
exit /b 0

:end
pause
endlocal