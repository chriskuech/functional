
Cmdlets for functional programming in PowerShell

# How does functional programming work in PowerShell?

## Processing arrays in pipelines with functions
Functional Programming is largely about applying functions to Lists to obtain different results.  PowerShell has good support for this as long as the function only takes a single argument, such as with filter functions and their implicit `$_` argument.

```PowerShell
# square each number
1..10 | % {$_ * $_}
```

## Functions as first-class objects
Functional Programming languages all support functions as first-class objects, which basically means that the function can be assigned to a variable.  PowerShell does not support functions as first-class objects—so how can PowerShell support functional programming?

PowerShell supports something similar to functions, called  `scriptblock`s, which *are* first-class objects.

```PowerShell
# define a scriptblock
$add = {
  Param($a, $b)
  $a + $b
}
```

You can also obtain a `scriptblock` from a PowerShell function.

```PowerShell
# reference the scriptblock from a function
function add($a, $b) {
  $a + $b
}
$add = $function:add
```

Or from a string.
```PowerShell
# load a script as a scriptblock
$add = [scriptblock](Get-Content add.ps1 -Raw)
```

You can invoke your scriptblock with access to variables in your current scope using `.` or without access to your current scope using `&`.

```PowerShell
# demonstrate invokation scoping
$constant = 14
function addWithConstant($a) {
  $a + $constant
}
.$function:add 3 # outputs `17` because `3 + 14 -eq 17`
&$function:add 3 # outputs `3` because `3 + $null -eq 17`
```

# How does this module help with functional programming?

Functional Programming is largely about applying functions to Lists to obtain different results.  PowerShell pipelines have amazing support for this, but of the three main Functional Programming functions, PowerShell only has support for two.

| Input | Output | Python function | PowerShell function |
|-|-|-|-|
| List, function | List of same length | `map` | `ForEach-Object` |
| List, function | List of smaller length | `filter` | `Where-Object` |
| List, function | Any type | `reduce` | *?* |

This module introduces two cmdlets:
* `Reduce-Object`, for applying a function to each element of the array and an accumulated value, and returning the acculated value.
* `Merge-Object`, for recursively merging two objects using a given strategy or a custom strategy.

```PowerShell
1..10 | Reduce-Object {$a + $b}
# outputs `55`

Merge-Object @{a = @{b = 1}} @{a = @{c = 2}} -Strategy Fail
# outputs `@{a = @{b = 1; c = 2}}`
```

Install the module with `Install-Module functional` and use the `help` cmdlet to learn more about each cmdlet.
