# Build the same Lua version used by the local regression suite from verified upstream source.
[CmdletBinding()]
param([string]$Destination=(Join-Path $env:RUNNER_TEMP 'yso-lua-5.4.8'))
$ErrorActionPreference='Stop'
$destinationPath=[IO.Path]::GetFullPath($Destination)
[IO.Directory]::CreateDirectory($destinationPath) | Out-Null
$archive=Join-Path $destinationPath 'lua-5.4.8.tar.gz'
Invoke-WebRequest -Uri 'https://www.lua.org/ftp/lua-5.4.8.tar.gz' -OutFile $archive
# Published at https://www.lua.org/ftp/ .
if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine '4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae'){throw 'Lua source checksum mismatch'}
& tar -xzf $archive -C $destinationPath
if($LASTEXITCODE -ne 0){throw 'Lua source extraction failed'}
$compiler=Get-Command gcc -ErrorAction SilentlyContinue
if(-not $compiler){
  foreach($candidate in @('C:/msys64/ucrt64/bin/gcc.exe','C:/msys64/mingw64/bin/gcc.exe','C:/mingw64/bin/gcc.exe')){
    if(Test-Path -LiteralPath $candidate){$compiler=Get-Item -LiteralPath $candidate;break}
  }
}
if(-not $compiler){throw 'A MinGW GCC compiler is required on the Windows CI runner'}
$compilerPath=if($compiler.Source){$compiler.Source}else{$compiler.FullName}
$env:PATH=(Split-Path $compilerPath -Parent)+';'+$env:PATH
$src=Join-Path $destinationPath 'lua-5.4.8/src'
Push-Location $src
try{
  $sources=@(Get-ChildItem -Filter '*.c' | Where-Object Name -notin @('lua.c','luac.c') | ForEach-Object {$_.FullName})
  & $compilerPath -std=gnu99 -O2 -DLUA_USE_WINDOWS -c @sources
  if($LASTEXITCODE -ne 0){throw 'Lua library compilation failed'}
  $objects=@(Get-ChildItem -Filter '*.o' | ForEach-Object {$_.FullName})
  & $compilerPath -std=gnu99 -O2 -DLUA_USE_WINDOWS -o lua.exe lua.c @objects
  if($LASTEXITCODE -ne 0){throw 'Lua interpreter compilation failed'}
  & $compilerPath -std=gnu99 -O2 -DLUA_USE_WINDOWS -o luac.exe luac.c @objects
  if($LASTEXITCODE -ne 0){throw 'Lua compiler compilation failed'}
}finally{Pop-Location}
if($env:GITHUB_PATH){Add-Content -LiteralPath $env:GITHUB_PATH -Value $src;Add-Content -LiteralPath $env:GITHUB_PATH -Value (Split-Path $compilerPath -Parent)}
Write-Output ('Lua tools: '+$src)
