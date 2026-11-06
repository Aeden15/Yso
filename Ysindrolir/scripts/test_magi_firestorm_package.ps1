param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Yso system.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$taskTemp=Join-Path ([IO.Path]::GetTempPath()) ('magi-firestorm-'+[guid]::NewGuid())
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
function Mask([string]$text){[regex]::Replace($text,'(?s)(<Script\b[^>]*>\s*<name>Magi firestorm</name>.*?)<script>.*?</script>','$1<script>MASKED</script>')}
New-Item -ItemType Directory -Path $taskTemp | Out-Null
try{
  $copy=Join-Path $taskTemp 'package.xml';Copy-Item -LiteralPath $PackagePath -Destination $copy
  $before=[IO.File]::ReadAllText($copy)
  [xml]$shipping=$before
  $shippingNodes=$shipping.SelectNodes('//Script[name="Magi firestorm"]/script')
  Assert ($shippingNodes.Count -eq 1) 'Expected exactly one shipping Firestorm script'
  Assert ($shippingNodes[0].InnerText -ceq [IO.File]::ReadAllText((Join-Path $root 'Magi/Magi_firestorm.lua'))) 'Shipping Firestorm source/native drift'
  & (Join-Path $PSScriptRoot 'build_magi_firestorm_package.ps1') -PackagePath $copy
  $after=[IO.File]::ReadAllText($copy)
  Assert ((Mask $before) -ceq (Mask $after)) 'Firestorm builder changed unrelated native content'
  & (Join-Path $PSScriptRoot 'build_magi_firestorm_package.ps1') -PackagePath $copy
  Assert ($after -ceq [IO.File]::ReadAllText($copy)) 'Firestorm build is not idempotent'
  [xml]$doc=$after;$nodes=$doc.SelectNodes('//Script[name="Magi firestorm"]/script')
  Assert ($nodes.Count -eq 1) 'Expected exactly one native Firestorm script'
  Assert ($nodes[0].InnerText -ceq [IO.File]::ReadAllText((Join-Path $root 'Magi/Magi_firestorm.lua'))) 'Exact Firestorm source/native drift'
  $luaPath=Join-Path $taskTemp 'firestorm.lua'
  [IO.File]::WriteAllText($luaPath,$nodes[0].InnerText,[Text.UTF8Encoding]::new($false))
  & luac -p $luaPath;Assert ($LASTEXITCODE -eq 0) 'Invalid embedded Firestorm Lua'
  & lua (Join-Path $root 'Yso/Tests and rebuilds/test_magi_firestorm.lua') ($root.Replace('\','/')+'/') $luaPath
  Assert ($LASTEXITCODE -eq 0) 'Embedded Firestorm behavioral regressions failed'
  Write-Host 'PASS: Firestorm scoped build, exact native parity, idempotence, syntax and embedded behavior'
}finally{
  $resolved=(Resolve-Path -LiteralPath $taskTemp).Path
  if((Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or
      (Split-Path $resolved -Leaf) -notlike 'magi-firestorm-*'){throw 'Unexpected test directory; refusing cleanup'}
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
