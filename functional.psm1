
##
# enums
#

enum MergeStrategy {
  Add
  Override
  Fail
}

enum ParamStyle {
  Implicit
  Explicit
  Infer
}

enum Direction {
  Left
  Right
}

##
# module variables
#

$Strategies = @{
  Add      = {
    Param($a, $b) 
    return $a + $b
  }
  Override = {
    Param($a, $b)
    return $b
  }
  Fail     = {
    Param($a, $b)
    throw "Cannot merge type '$($a.GetType())' and '$($b.GetType())'"
  }
}

##
# helper functions
#

# don't use `-is [PSCustomObject]`
# https://github.com/PowerShell/PowerShell/issues/9557
function isPsCustomObject($v) {
  $v.PSTypeNames -contains 'System.Management.Automation.PSCustomObject'
}

# recursively test $a and $b for deep equality
function recursiveEquality($a, $b) {
  if ($a -is [array] -and $b -is [array]) {
    Write-Debug "recursively test arrays '$a' '$b'"
    if ($a.Count -ne $b.Count) {
      return $false
    }
    $inequalIndexes = 0..($a.Count - 1) | ? { -not (recursiveEquality $a[$_] $b[$_]) }
    return $inequalIndexes.Count -eq 0
  }
  if ($a -is [hashtable] -and $b -is [hashtable]) {
    Write-Debug "recursively test hashtable '$a' '$b'"
    $inequalKeys = $a.Keys + $b.Keys `
    | Sort-Object -Unique `
    | ? { -not (recursiveEquality $a[$_] $b[$_]) }
    return $inequalKeys.Count -eq 0
  }
  if ((isPsCustomObject $a) -and (isPsCustomObject $b)) {
    Write-Debug "a is pscustomobject: $($a -is [psobject])"
    Write-Debug "recursively test objects '$a' '$b'"
    $inequalKeys = $a.psobject.Properties + $b.psobject.Properties `
    | % Name `
    | Sort-Object -Unique `
    | ? { -not (recursiveEquality $a.$_ $b.$_) }
    return $inequalKeys.Count -eq 0
  }
  Write-Debug "test leaves '$a' '$b'"
  return $a.GetType() -eq $b.GetType() -and $a -eq $b
}

# merge `$a` and `$b` recursively.  If `$a` and `$b` cannot be merged,
# pass `$a` and `$b` to `$strategy` to resolve the conflict.
function recursiveMerge($a, $b, [scriptblock]$strategy) {
  if ($null -eq $a) {
    Write-Debug "new assignment '$b'"
    return $b
  }
  if ($a -eq $b -or $null -eq $b) {
    Write-Debug "existing assignment '$a'"
    return $a
  }
  if ($a -is [array] -and $b -is [array]) {
    Write-Debug "merge arrays '$a' '$b'"
    return $a + $b | Sort-Object -Unique
  }
  if ($a -is [hashtable] -and $b -is [hashtable]) {
    Write-Debug "merge hashtable '$a' '$b'"
    $merged = @{ }
    $a.Keys + $b.Keys `
    | Sort-Object -Unique `
    | % { $merged[$_] = recursiveMerge $a[$_] $b[$_] $strategy }
    return $merged
  }
  if ((isPsCustomObject $a) -and (isPsCustomObject $b)) {
    Write-Debug "a is pscustomobject: $($a -is [psobject])"
    Write-Debug "merge objects '$a' '$b'"
    $merged = @{ }
    $a.psobject.Properties + $b.psobject.Properties `
    | % Name `
    | Sort-Object -Unique `
    | % { $merged[$_] = recursiveMerge $a.$_ $b.$_ $strategy }
    return [PSCustomObject]$merged
  }
  Write-Debug "resolve conflict '$a' '$b'"
  return &$strategy $a $b 
}

##
# exported functions
#

<#
.SYNOPSIS
  Merges all the input objects using the specified conflict resolution strategy
.OUTPUTS
  The merged value
#>
function Merge-Object {
  Param(
    # The objects to merge
    [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "Named")]
    [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "Explicit")]
    [ValidateNotNullOrEmpty()]
    [object[]] $Object,
    # The conflict resolution strategy
    [Parameter(Mandatory, ParameterSetName = "Named")]
    [ValidateNotNullOrEmpty()]
    [MergeStrategy] $Strategy,
    # Resolves merge conflicts between two objects
    [Parameter(Mandatory, ParameterSetName = "Explicit")]
    [ValidateScript( { $_.Ast.ParamBlock.Parameters.Count -in (0, 2) } )]
    [scriptblock] $Resolver
  )

  if (-not $Resolver) {
    $Resolver = $Strategies["$Strategy"]
  }

  # we need to use explicit params because implicit params are invoked in a closure,
  # whereas we need our scriptblock to have access to $Strategies
  $reducer = { Param($a, $b); recursiveMerge $a $b $Resolver }
  $input | Reduce-Object $reducer
}

function Merge-ScriptBlock {
  [OutputType([scriptblock])]
  Param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateScript( { $_ | % { $_.Ast.ParamBlock.Parameters.Count -eq 1 } | Test-All } )]
    [scriptblock[]] $ScriptBlock
  )

  $reducer = { Param($a, $b) { Param($arg) &$a (&$b $arg) }.GetNewClosure() }
  $input | Reduce-Object $reducer
}

<#
.SYNOPSIS
  Reduces a pipeline with the given reducer function
.OUTPUTS
  The accumulated value
.NOTES
  Reduce is an unapproved Verb, but none of the approved verbs accurately describe what we're doing,
  so we are conforming to Verb-Noun convention like other *-Object cmdlets instead
#>
function Reduce-Object {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
  Param(
    # The function applied to the accumulator and each element of the input
    [Parameter(Mandatory)]
    [ValidateScript( { $_.Ast.ParamBlock.Parameters.Count -in (0, 2) } )]
    [scriptblock] $Reducer,
    # The objects to merge
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [object[]] $Object,
    [ParamStyle] $ParamStyle = "Infer",
    [Direction] $Direction = "Right"
  )

  # deduce and validate scriptblock invokation style
  $paramCount = $Reducer.Ast.ParamBlock.Parameters.Count
  $implicit = $ParamStyle -ne "Explicit" -and $paramCount -eq 0
  $explicit = $ParamStyle -ne "Implicit" -and $paramCount -eq 2
  if (-not ($implicit -or $explicit)) {
    throw "Could not reconcile Reducer parameter count '$paramCount' with param declaration style '$ParamStyle'"
  }

  # normalize input
  if ($Direction -eq [Direction]::Left) {
    [array]::Reverse($input)
  }

  # invoke the reducer
  $accum = $input | Select -First 1
  if ($implicit) {
    foreach ($object in $input | Select -Skip 1) {
      # invoke in scriptblock to minimize exposure of local variables
      $safelyScoped = {
        Param($a, $b, [scriptblock]$reducer)
        . $reducer.GetNewClosure()
      }
      $accum = &$safelyScoped $accum $object $Reducer
    }
  }
  if ($explicit) {
    foreach ($object in $input | Select -Skip 1) {
      $accum = &$Reducer $accum $object
    }
  }
  return $accum
}

<#
.SYNOPSIS
Returns true if all elements in the pipeline are truthy
#>

filter Test-All {
  [OutputType([boolean])]
  Param()
  
  begin {
    $results = @()
  }
  process {
    $results += $_
  }
  end {
    foreach($result in $results){
      if(-not $result){
        return $false
      }
    }
    return $true
  }
}

<#
.SYNOPSIS
Returns true if any of the elements in the pipeline are truthy
#>

filter Test-Any {
  [OutputType([boolean])]
  Param()

  begin {
    $results = @()
  }
  process {
    $results += $_
  }
  end {
    # foreach($result in $results){
    #   if($result -isnot [bool] -and $result -isnot [int]){
    #     return false
    #   }
    # }
    # return ($results -contains $true) 
    foreach($result in $results){
      if((-not $result) -eq $false){
        return $true
      }
    }
    #return ($results -contains $true) 
    return $false
  }
}

<#
.SYNOPSIS
Returns true if all elements in the pipeline are equival
.DESCRIPTION
Compares each element in the pipeline to the first pipeline element using a 
deep/recursive equality check of the properties and items
#>

function Test-Equality {
  [OutputType([boolean])]
  Param(
    # The objects to compare for equality
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [object[]] $Object
  )

  $head = $input | Select -First 1
  $input | Select -Skip 1 | % { recursiveEquality $head $_ } | Test-All
}

##
# aliases
#
New-Alias -Name "merge" -Value Merge-Object
New-Alias -Name "reduce" -Value Reduce-Object
New-Alias -Name "forall" -Value Test-All
New-Alias -Name "exists" -Value Test-Any
