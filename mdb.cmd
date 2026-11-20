@echo off
setlocal
set "ROOT=%~dp0"
pushd "%ROOT%" >nul
if exist "bin\mdb.exe" (
  powershell -NoProfile -Command "if (@(Get-ChildItem cmd,pkg -Recurse -Filter *.go | Where-Object { $_.LastWriteTime -gt (Get-Item 'bin\mdb.exe').LastWriteTime }).Count -gt 0 -or (Get-Item 'go.mod').LastWriteTime -gt (Get-Item 'bin\mdb.exe').LastWriteTime) { exit 1 }" >nul 2>&1
  if not errorlevel 1 (
    "bin\mdb.exe" %*
    set "RC=%ERRORLEVEL%"
    popd >nul
    exit /b %RC%
  )
)
where go >nul 2>&1
if errorlevel 1 (
  echo Error: Go toolchain not found and bin\mdb.exe is missing or stale. 1>&2
  popd >nul
  exit /b 1
)
go run ./cmd/mdb %*
set "RC=%ERRORLEVEL%"
popd >nul
exit /b %RC%
