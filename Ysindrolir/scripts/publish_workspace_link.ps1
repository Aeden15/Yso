[CmdletBinding(SupportsShouldProcess=$true)]
param([switch]$ValidateOnly,[string]$PackageDirectory=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$inputs=@{}
$metadata=@{}
$count=0
foreach($name in @('AK','Yso system')){
 $bytes=[IO.File]::ReadAllBytes((Join-Path $PackageDirectory ($name+'.xml')))
 $text=[Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
 $doc=[xml]$text
 if($doc.DocumentElement.Name -cne 'MudletPackage'){throw ('Invalid Mudlet root: '+$name)}
 $chunks=[Collections.Generic.List[string]]::new()
 foreach($node in $doc.SelectNodes('//script')){
  $body=$node.InnerText
  if([string]::IsNullOrWhiteSpace($body)){continue}
  $chunks.Add(([Text.Encoding]::UTF8.GetByteCount($body)).ToString()+"`n"+$body)
  $count++
 }
 $inputs[$name]=$bytes
 $metadata[$name]=$chunks -join ''
}
if($ValidateOnly){Write-Output ('PASS both XMLs parse; extracted '+$count+' Lua bodies for native Mudlet syntax preflight');return}
$destination=Join-Path $root '.workspace-link-publish'
if($PSCmdlet.ShouldProcess($destination,'Publish byte-exact XML validation snapshots')){
 [IO.Directory]::CreateDirectory($destination) | Out-Null
 foreach($name in @('AK','Yso system')){
  $prefix=[Text.Encoding]::UTF8.GetBytes($inputs[$name].Length.ToString()+"`n")
  $metadataBytes=[Text.Encoding]::UTF8.GetBytes($metadata[$name])
  $receipt=[byte[]]($prefix+$inputs[$name]+$metadataBytes)
  $target=Join-Path $destination ($name+'.validated')
  $pending=$target+'.tmp'
  [IO.File]::WriteAllBytes($pending,$receipt)
  [IO.File]::Move($pending,$target,$true)
 }
 Write-Output ('PASS published XML validation snapshots and '+$count+' Lua bodies; Mudlet validates syntax before replacement')
}
