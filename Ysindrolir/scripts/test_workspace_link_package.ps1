$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$doc=[xml][IO.File]::ReadAllText((Join-Path $root 'mudlet packages/Yso Workspace Link.xml'))
$body=$doc.SelectSingleNode('//Script[name="Achaea workspace link controller"]').script
$source=[IO.File]::ReadAllText((Join-Path $root 'Yso/Integration/workspace_link.lua'))
if($source -cne $body){throw 'Workspace link source/package drift'}
foreach($entry in @(@('^ysolink$','YsoWorkspaceLink.link()'),@('^ysoreload$','YsoWorkspaceLink.reload()'),@('^ysostatus$','YsoWorkspaceLink.status()'))){
 $alias=@($doc.SelectNodes('//Alias') | Where-Object {$_.regex -ceq $entry[0]})
 if($alias.Count -ne 1 -or $alias[0].script -cne $entry[1] -or $alias[0].isActive -ne 'yes'){throw ('Invalid permanent alias: '+$entry[0])}
}
if($doc.SelectNodes('//Trigger').Count -ne 0){throw 'Workspace link must not introduce game triggers'}
$luaRoot=$root.Replace('\','/')
$code='local original=dofile;local source=[====['+$body+']====];dofile=function(p) if p:match("/Integration/workspace_link.lua$") then return assert(load(source))() end return original(p) end;arg={[1]=[==['+$luaRoot+']==]};original([==['+$luaRoot+'/Yso/Tests and rebuilds/test_workspace_link.lua]==])'
$code | & lua -
if($LASTEXITCODE -ne 0){throw 'Packaged bridge tests failed'}
Write-Output 'PASS standalone Achaea bridge package, permanent aliases, source parity and embedded behavior'
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('yso-link-test-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($fixture) | Out-Null
try{
 [IO.File]::WriteAllText((Join-Path $fixture 'AK.xml'),'<MudletPackage />')
 [IO.File]::WriteAllText((Join-Path $fixture 'Yso system.xml'),'<MudletPackage><broken></MudletPackage>')
 $rejected=$false
 try{& (Join-Path $PSScriptRoot 'publish_workspace_link.ps1') -ValidateOnly -PackageDirectory $fixture}catch{$rejected=$true}
 if(-not $rejected){throw 'Publisher accepted malformed XML'}
 Write-Output 'PASS publisher rejects malformed XML before publishing snapshots'
}finally{
 Remove-Item -LiteralPath (Join-Path $fixture 'AK.xml'),(Join-Path $fixture 'Yso system.xml') -Force
 Remove-Item -LiteralPath $fixture -Force
}
