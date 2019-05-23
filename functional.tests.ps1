
Import-Module $PSScriptRoot -Force

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
