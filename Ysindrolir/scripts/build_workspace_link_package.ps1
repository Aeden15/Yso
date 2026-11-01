[CmdletBinding(SupportsShouldProcess=$true)]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$source=[IO.File]::ReadAllText((Join-Path $root 'Yso/Integration/workspace_link.lua'))
function Escape([string]$s){[Security.SecurityElement]::Escape($s)}
$aliases=@(
 @('Link Achaea workspace','^ysolink$','YsoWorkspaceLink.link()'),
 @('Reload Achaea workspace','^ysoreload$','YsoWorkspaceLink.reload()'),
 @('Achaea workspace status','^ysostatus$','YsoWorkspaceLink.status()')
)
$aliasXml=''
foreach($a in $aliases){
 $aliasXml+='<Alias isActive="yes" isFolder="no"><name>'+$a[0]+'</name><script>'+(Escape $a[2])+'</script><command /><packageName /><regex>'+$a[1]+'</regex></Alias>'
}
$text='<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE MudletPackage><MudletPackage version="1.001"><AliasPackage><AliasGroup isActive="yes" isFolder="yes"><name>Achaea workspace link</name><script /><command /><packageName /><regex />'+$aliasXml+'</AliasGroup></AliasPackage><ScriptPackage><Script isActive="yes" isFolder="no"><name>Achaea workspace link controller</name><packageName /><script>'+(Escape $source)+'</script><eventHandlerList /></Script></ScriptPackage></MudletPackage>'
[void][xml]$text
$destination=Join-Path $root 'mudlet packages/Yso Workspace Link.xml'
if($PSCmdlet.ShouldProcess($destination,'Build independent Achaea workspace-link package')){
 [IO.File]::WriteAllText($destination,$text,[Text.UTF8Encoding]::new($false))
}
