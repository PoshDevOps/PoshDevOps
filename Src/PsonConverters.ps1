﻿
function ConvertFrom-Pson(
[string]
[Parameter(
    ValueFromPipeline=$true)]
$Pson) {
    Invoke-Expression -Command $Pson | Write-Output
}

function ConvertTo-Pson(
[Parameter(
    Position=0,
    Mandatory=$true,
    ValueFromPipeline=$true)]
[AllowNull()] 
$inputObject,

[Int]
[Parameter(
    Position=1,
    Mandatory=$false,
    ValueFromPipeline=$false)] 
$depth=16,

[Int]
[Parameter(
    Position=2,
    Mandatory=$false,
    ValueFromPipeline=$false)]
$NestingLevel=1) {

<#
 .SYNOPSIS
   creates a powershell object-notation script that generates the same object data
 .DESCRIPTION
   This produces 'PSON', the powerShell-equivalent of JSON from any object you pass to it. It isn't suitable for the huge objects produced by some of the cmdlets such as Get-Process, but fine for simple objects
 .EXAMPLE
   $array=@()
   $array+=Get-Process wi* |  Select-Object Handles,NPM,PM,WS,VM,CPU,Id,ProcessName 
   ConvertTo-Pson $array

 .PARAMETER Object 
   the object that you want scripted out
 .PARAMETER Depth
   The depth that you want your object scripted to
 .PARAMETER Nesting Level
   internal use only. required for formatting
#>
    
BEGIN {}
PROCESS {
 If ($inputObject -eq $Null) {$p+='$Null'; return $p} # if it is null return null
 $padding=[string]'  ' * $NestingLevel # lets just create our left-padding for the block
 try {
  $Type = $inputObject.GetType().Name # we start by getting the object's type 
  if  ($Type -ieq 'Object[]') {$Type = "$($inputObject.GetType().BaseType.Name)"} # see what it really is
  if ($depth -ilt $NestingLevel) {$Type = 'OutOfDepth'} #report the leaves in terms of object type
  elseif  ($Type -ieq 'XmlDocument') {$Type = 'xml'} # convert to PS Alias
  elseif  ($Type -ieq 'XmlElement') {$Type = 'xml'} # convert to PS Alias
  # prevent these values being identified as an object
  if (@('boolean','byte','char','datetime','decimal','double','float','single','guid','int','int32',
      'int16','long','int64','OutOfDepth','RuntimeType','PSNoteProperty','regex','sbyte','string',
      'timespan','uint16','uint32','uint64','uri','version','void','xml','datatable','List`1',
      'SqlDataReader', 'datarow', 'ScriptBlock', 'type') -notcontains $type) {      
    if  ($Type -ieq 'OrderedDictionary') {$Type = 'HashTable'}
    elseif  ($Type -ieq 'PSCustomObject') {$Type = 'PSObject'} #
    elseif  ($inputObject -is "Array") {$Type = 'Array'} # whatever it thinks it is called
    elseif ($inputObject -is "HashTable") {$Type = 'HashTable'} # for our purposes it is a hashtable
    elseif (($inputObject|gm -membertype Properties | Select name| Where name -like 'Keys') -ne $null ) {$Type='generic'} #use dot notation
    elseif (($inputObject|gm -membertype Properties | Select name).count -gt 1) {$Type='Object'}
   }
  write-verbose "$($padding)Type:='$Type', Object type:=$($inputObject.GetType().Name), BaseName:=$($inputObject.GetType().BaseType.Name) $NestingLevel "
  switch ($Type)
  {
  'ScriptBlock'{"[$type] {$($inputObject.ToString())}"}
  'xml'        { "[$type]@'`r`n"+($inputObject.OuterXMl) +"`r`n'@`r`n" } # just use a 'here' string
  'DateTime'   {"[datetime]'$($inputObject.ToString('s'))'"} # s=SortableDateTimePattern (based on ISO 8601) local time
  'Boolean'    {"[bool] $(&{if ($inputObject -eq $true) {"`$True"} Else {"`$False"}})"}
  'string'     {if ($inputObject  -match '[\r\n]') {"@'`r`n$inputObject`r`n'@"} else {"'$($inputObject -replace '''','''''')'"}} 
  'Char'       {[int]$inputObject} 
  {@('byte','decimal','double','float','single','int','int32','int16','long','int64','sbyte','uint16','uint32','uint64') -contains $_}   
               {"$inputObject"} # rendered as is without single quotes
  'PSNoteProperty' { "$(ConvertTo-PSON -inputObject $inputObject.Value -depth $depth -NestingLevel ($NestingLevel))"}
  'Array'      {"`r`n$padding@("+ ("$($inputObject | ForEach {",$(ConvertTo-PSON -inputObject $_ -depth $depth -NestingLevel ($NestingLevel+1))"})".Substring(1))+"`r`n$padding)"}
  'HashTable'  {"`r`n$padding@{"+ ("$($inputObject.GetEnumerator() | ForEach {"; '$($_.Name)' = " +  (ConvertTo-PSON -inputObject $_.Value -depth $depth -NestingLevel ($NestingLevel+1))})".Substring(1)+"`r`n$padding}")}
  'PSObject'   {"`r`n$padding[pscustomobject]@{"+ ("$($inputObject.PSObject.Properties | ForEach {"; '$($_.Name)' = " + (ConvertTo-PSON -inputObject $_ -depth $depth  -NestingLevel ($NestingLevel+1))})".Substring(1)+"`r`n$padding}")}
  'Dictionary' {"`r`n$padding@{"+ ($inputObject.item | ForEach {'; '+"'$_'" + " = " + (ConvertTo-PSON -inputObject $inputObject.Value[$_] -depth $depth  -NestingLevel $NestingLevel+1)})+'}'}
  'Generic'    {"`r`n$padding@{"+ ("$($inputObject.Keys | ForEach {";  $_ =  $(ConvertTo-PSON -inputObject $inputObject.$_ -depth $depth  -NestingLevel ($NestingLevel+1))"})".Substring(1)+"`r`n$padding}")}
  'Object'     {"`r`n$padding@{"+ ("$($inputObject| Get-Member -membertype properties  | Select-Object name | ForEach {";  $($_.name) =  $(ConvertTo-PSON -inputObject $inputObject.$($_.name) -depth $NestingLevel  -NestingLevel ($NestingLevel+1))"})".Substring(1)+"`r`n$padding}")}
  'Datatable'  {"`r`n$padding@{"+ ("$($inputObject.TableName)=`r`n$padding @("+"$($inputObject | ForEach {",$(ConvertTo-PSON -inputObject $_ -depth $depth -NestingLevel ($NestingLevel+1))"})".Substring(1)+"`r`n$padding  )`r`n$padding}")}
  'DataRow'    {"`r`n$padding@{"+ ("$($inputObject| Get-Member -membertype properties  | Select-Object name | ForEach {"; $($_.name)=  $(ConvertTo-PSON -inputObject $inputObject.$($_.name) -depth $depth  -NestingLevel ($NestingLevel+1))"})".Substring(1)+"}")}
   default     {"'$inputObject'"}
   }
  }
  catch { write-error "Error'$($_)' in script $($_.InvocationInfo.ScriptName) $($_.InvocationInfo.Line.Trim()) (line $($_.InvocationInfo.ScriptLineNumber)) char $($_.InvocationInfo.OffsetInLine) executing $($_.InvocationInfo.MyCommand) on $type object '$($inputObject.Name)' Class: $($inputObject.GetType().Name) BaseClass: $($inputObject.GetType().BaseType.Name) " 
   }
  finally{} 
  }
 END {}
}



