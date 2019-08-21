
Import-Module $PSScriptRoot -DisableNameChecking -Force

Describe "Reduce-Object" {
  Context "Given various invalid parameter invokations" {
    It "Should throw for invalid ParamStyle" {
      { 1..10 | Reduce-Object { } -ParamStyle "Joe Estevez" } | Should -Throw
    }
    It "Should throw for implicit params and 'Explicit'" {
      { 1..10 | Reduce-Object { $a + $b } -ParamStyle "Explicit" } | Should -Throw
    }
    It "Should throw for explicit params and 'Implicit'" {
      { 1..10 | Reduce-Object { Param($a, $b); $a + $b } -ParamStyle "Implicit" } | Should -Throw
    }
  }
  Context "Given various valid parameter invokations" {
    It "Should not throw for implicit params and 'Implicit'" {
      { 1..10 | Reduce-Object { $a + $b } -ParamStyle "Implicit" } | Should -Not -Throw
    }
    It "Should not throw for explicit params and 'Explicit'" {
      { 1..10 | Reduce-Object { Param($a, $b); $a + $b } -ParamStyle "Explicit" } | Should -Not -Throw
    }
    It "Should not throw for implicit params and 'Infer'" {
      { 1..10 | Reduce-Object { $a + $b } -ParamStyle "Infer" } | Should -Not -Throw
    }
    It "Should not throw for explicit params and 'Infer'" {
      { 1..10 | Reduce-Object { Param($a, $b); $a + $b } -ParamStyle "Infer" } | Should -Not -Throw
    }
  }
  Context "Given an implicit sum reducer" {
    It "Should sum up the numbers" {
      $values = 1..10
      $reducer = { $a + $b }
      $reduced = $values | Reduce-Object $reducer
      $measured = $values | Measure-Object -Sum | % Sum
      $reduced | Should -Be $measured
    }
    It "Should not have access to the parent scope" {
      $values = 1..10
      $c = 42
      $reducer = { $c }
      $reduced = $values | Reduce-Object $reducer
      $reduced | Should -Be $null
    }
  }
  Context "Given an explicit sum reducer" {
    It "Should sum up the numbers" {
      $values = 1..10
      $reducer = { Param($a, $b); $a + $b }
      $reduced = $values | Reduce-Object $reducer
      $measured = $values | Measure-Object -Sum | % Sum
      $reduced | Should -Be $measured
    }
  }
}

Describe "Merge-Object" {
  Context "Given an 'Override' merge strategy" {
    It "Should merge arrays without duplicates" {
      $merged = (1..5), (6..10) | Merge-Object -Strategy Override
      $merged | Should -BeOfType [int]
      $merged | Should -HaveCount 10
    }
    It "Should merge arrays with duplicates" {
      $merged = (1..7), (4..12) | Merge-Object -Strategy Override
      $merged | Should -BeOfType [int]
      $merged | Should -HaveCount 12
    }
    It "Should merge hashtables without duplicates" {
      $merged = @{ a = 1 }, @{ b = 2 } `
      | Merge-Object -Strategy Override
      $merged | Should -BeOfType [hashtable]
      $merged.Keys | Should -HaveCount 2
    }
    It "Should merge hashtables with duplicates" {
      $merged = @{ a = 1; b = 2 }, @{ b = 3; c = 4 } `
      | Merge-Object -Strategy Override
      $merged | Should -BeOfType [hashtable]
      $merged.Keys | Should -HaveCount 3
      $merged["b"] | Should -Be 3
    }
    It "Should merge objects without duplicates" {
      $merged = @{ a = 1 }, @{ b = 2 } `
      | % { [PSCustomObject]$_ } `
      | Merge-Object -Strategy Override
      $merged | Should -BeOfType [PSCustomObject]
      $merged.psobject.Properties | Should -HaveCount 2
    }
    It "Should merge objects with duplicates" {
      $merged = @{ a = 1; b = 2 }, @{ b = 3; c = 4 } `
      | % { [PSCustomObject]$_ } `
      | Merge-Object -Strategy Override
      $merged | Should -BeOfType [PSCustomObject]
      $merged.psobject.Properties | Should -HaveCount 3
      $merged.b | Should -Be 3
    }
    It "Should override inequal strings" {
      $merged = "joe", "estevez" | Merge-Object -Strategy Override
      $merged | Should -Be "estevez"
    }
    It "Should override inequal values" {
      $merged = "cat", 42 | Merge-Object -Strategy Override
      $merged | Should -Be 42
    }
    It "Should override equal values" {
      $merged = "cat", "cat" | Merge-Object -Strategy Override
      $merged | Should -Be "cat"
    }
  }
  Context "Given a 'Fail' merge strategy" {
    It "Should merge arrays without duplicates" {
      $merged = (1..5), (6..10) | Merge-Object -Strategy Fail
      $merged | Should -BeOfType [int]
      $merged | Should -HaveCount 10
    }
    It "Should merge arrays with duplicates" {
      $merged = (1..7), (4..12) | Merge-Object -Strategy Fail
      $merged | Should -BeOfType [int]
      $merged | Should -HaveCount 12
    }
    It "Should merge hashtables without duplicates" {
      $merged = @{ a = 1 }, @{ b = 2 } `
      | Merge-Object -Strategy Fail
      $merged | Should -BeOfType [hashtable]
      $merged.Keys | Should -HaveCount 2
    }
    It "Should fail to merge hashtables with duplicates" {
      {
        @{ a = 1; b = 2 }, @{ b = 3; c = 4 } `
        | Merge-Object -Strategy Fail
      } | Should -Throw
    }
    It "Should merge objects without duplicates" {
      $merged = @{ a = 1 }, @{ b = 2 } `
      | % { [PSCustomObject]$_ } `
      | Merge-Object -Strategy Fail
      $merged | Should -BeOfType [PSCustomObject]
      $merged.psobject.Properties | Should -HaveCount 2
    }
    It "Should fail to merge objects with duplicates" {
      {
        @{ a = 1; b = 2 }, @{ b = 3; c = 4 } `
        | % { [PSCustomObject]$_ } `
        | Merge-Object -Strategy Fail
      } | Should -Throw
    }
    It "Should fail to merge inequal strings" {
      { "joe", "estevez" | Merge-Object -Strategy Fail } `
      | Should -Throw
    }
    It "Should fail to merge inequal values" {
      { "cat", 42 | Merge-Object -Strategy Fail } `
      | Should -Throw
    }
    It "Should merge equal values" {
      $merged = "cat", "cat" | Merge-Object -Strategy Fail
      $merged | Should -Be "cat"
    }
  }
  Context "Given a resolver" {
    It "Should apply the resolver to irreconcilable types" {
      function resolver($a, $b) {
        $a + $b
      }
      $a = @{a = 1; b = 2 }
      $b = @{b = 3; d = 4 }
      $merged = ($a, $b) | Merge-Object -Resolver $Function:resolver
      $merged | Should -BeOfType [hashtable]
      $merged.Keys | Should -HaveCount 3
      $merged["b"] | Should -Be 5
    }
  }
}

Describe "Merge-ScriptBlock" {
  Context "Given valid input" {
    It "Should compose functions" {
      $fs = @(
        { Param($arg) "a" + $arg },
        { Param($arg) "b" + $arg },
        { Param($arg) "c" + $arg },
        { Param($arg) "d" + $arg }
      )
      $composed = $fs | Merge-ScriptBlock
      &$composed "e" | Should -Be "abcde"
    }
  }
  # # This is throwing a false negative: https://github.com/PowerShell/PowerShell/issues/9740
  # Context "Given invalid input" {
  #   It "Should fail if one of the scriptblocks has invalid params" {
  #     $fs = @(
  #       { Param($arg) "a" + $arg },
  #       { Param($arg1, $arg2) "b" + $arg1 },
  #       { Param($arg) "c" + $arg },
  #       { Param($arg) "d" + $arg }
  #     )
  #     { $fs | Merge-ScriptBlock } | Should -Throw
  #   }
  # }
}

Describe "Test-All" {
  Context "Given valid input" {
    It "Should allow non-boolean values" {
      @(1, 3, "a", "chris", @{a = 3 }) | Test-All | Should -BeTrue
    }
    It "Should allow boolean values" {
      $true, $true, $true, $true, $true | Test-All | Should -BeTrue
    }
  }
  Context "Given invalid input" {
    It "Should allow non-boolean values" {
      1, 3, "", "chris", @{a = 3 } | Test-All | Should -BeFalse
    }
    It "Should allow boolean values" {
      $true, $false, $true, $true, $true | Test-All | Should -BeFalse
    }
  }
  Context "Given single value" {
    It "Should pass on true" {
      $true | Test-All | Should -BeTrue
    }
    It "Should fail on false" {
      $false | Test-All | Should -BeFalse
    }
  }
}

Describe "Test-Any" {
  Context "Given valid input" {
    It "Should allow non-boolean values" {
      @(0, 1, 0, 0) | Test-Any | Should -BeTrue
    }
    It "Should allow boolean values" {
      $false, $true, $true, $false, $true | Test-Any | Should -BeTrue
    }
  }
  Context "Given invalid input" {
    It "Should allow non-boolean values" {
      @(0, 0, "", @(), 0) | Test-Any | Should -BeFalse
    }
    It "Should allow boolean values" {
      $false, $false, $false, $false, $false | Test-Any | Should -BeFalse
    }
  }
  Context "Given single value" {
    It "Should pass on true" {
      $true | Test-Any | Should -BeTrue
    }
    It "Should fail on false" {
      $false | Test-Any | Should -BeFalse
    }
  }
}

Describe "Test-Equality" {
  Context "Given leaves" {
    It "Should be true for equal values of the same type" {
      3, 3 | Test-Equality | Should  -BeTrue
    }
    It "Should be false for equal values of different types" {
      3, "3" | Test-Equality | Should -BeFalse
    }
  }
  Context "Given arrays" {
    It "Should be false for deep inequal values" {
      @(1, 2, @{a = 1 }, 3), @(1, 2, @{a = 2 }, 3) | Test-Equality | Should -BeFalse
    }
    It "Should be true for deep equal values" {
      @(1, 2, @{a = 1 }, 3), @(1, 2, @{a = 1 }, 3) | Test-Equality | Should -BeTrue
    }
  }
  Context "Given hashtables" {
    It "Should be false for deep inequal values" {
      @{a = 1; b = @{c = 2 } }, @{a = 1; b = [pscustomobject]@{c = 2 } } | Test-Equality | Should -BeFalse
    }
    It "Should be true for deep equal values" {
      @{a = 1; b = @{c = 2 } }, @{a = 1; b = @{c = 2 } } | Test-Equality | Should -BeTrue
    }
  }
  Context "Given an array of PSCustomObject" {
    $a = @([PSCustomObject]@{ 'Name' = 'Foo'; 'Value' = 'Foo' }, [PSCustomObject]@{ 'Name' = 'Baz'; 'Value' = 'Baz'  } )
    $b = @([PSCustomObject]@{ 'Name' = 'xxx'; 'Value' = 'Foo' }, [PSCustomObject]@{ 'Name' = 'Baz'; 'Value' = 'Baz'  } )
    It "Should be false for deep inequal values" {      
      $a, $b | Test-Equality | Should -BeFalse
    }
  }
}
