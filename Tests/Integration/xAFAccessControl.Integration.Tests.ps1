#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xAFAccessControl'
$IsVerbose = $false
# Import Helper.
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'Tests' -ChildPath (Join-Path -Path 'TestHelpers' -ChildPath 'CommonTestHelper.psm1'))) -Force

$TestEnvironment = Initialize-TestEnvironment -DSCModuleName $script:DSCModuleName -DSCResourceName $script:DSCResourceName

function Invoke-TestSetup {

}

function Invoke-TestCleanup {
    Restore-TestEnvironment -TestEnvironment $TestEnvironment

}

#endregion HEADER

# Begin Testing
try {
    Invoke-TestSetup
    $resultsFolder = Join-Path -Path (Split-Path -Path $PSScriptRoot) -ChildPath "Results"
    $startDscConfigurationParameters = @{
        Path         = $resultsFolder
        ComputerName = 'localhost'
        Wait         = $true
        Verbose      = $IsVerbose
        Force        = $true
        ErrorAction  = 'Stop'
    }
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $configFile

    Describe "$script:DSCResourceName\Integration" {

        $configurationName = "$($script:DSCResourceName)_Set"

        Context "When using configuration $($configurationName)" {
            $OutputPath = Join-Path -Path $resultsFolder -ChildPath $configurationName
            $configurationParameters = @{
                Access            = "Read, ReadData"
                OutputPath        = $OutputPath
                ConfigurationData = $ConfigurationData
            }
            It 'Should compile and apply the MOF without throwing' {
                {
                    & $configurationName @configurationParameters

                    $startDscConfigurationParameters["Path"] = $OutputPath
                    Start-DscConfiguration @startDscConfigurationParameters
                } | Should -Not -Throw
            }

            It 'Should call Get-DscConfiguration without error' {
                { $script:currentConfiguration = Get-DscConfiguration -Verbose:$IsVerbose -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should set the resource with all the correct parameters' {
                $resourceCurrentState = $script:currentConfiguration | Where-Object {
                    $_.ConfigurationName -eq $configurationName -and $_.CimClassName -eq $script:DSCResourceName
                }
                foreach ($resource in $resourceCurrentState) {
                    $resource.Access | Should -Match $configurationParameters.Access
                    $resource.Ensure | Should -Be "Present"
                }
            }
        }

        $configurationName = "$($script:DSCResourceName)_Remove"

        Context "When using configuration $($configurationName)" {
            $OutputPath = Join-Path -Path $resultsFolder -ChildPath $configurationName
            $configurationParameters = @{
                OutputPath        = $OutputPath
                ConfigurationData = $ConfigurationData
            }
            It 'Should compile and apply the MOF without throwing' {
                {
                    & $configurationName @configurationParameters

                    $startDscConfigurationParameters["Path"] = $OutputPath
                    Start-DscConfiguration @startDscConfigurationParameters
                } | Should -Not -Throw
            }

            It 'Should call Get-DscConfiguration without error' {
                { $script:currentConfiguration = Get-DscConfiguration -Verbose:$IsVerbose -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should set the resource with all the correct parameters' {
                $resourceCurrentState = $script:currentConfiguration | Where-Object {
                    $_.ConfigurationName -eq $configurationName -and $_.CimClassName -eq $script:DSCResourceName
                }
                foreach ($resource in $resourceCurrentState) {
                    $resource.Ensure | Should -Be "Absent"
                }
            }
        }
    }
}
finally {
    $configurationName = "$($script:DSCResourceName)_CleanUp"
    $OutputPath = Join-Path -Path $resultsFolder -ChildPath $configurationName
    $configurationParameters = @{
        OutputPath        = $OutputPath
        ConfigurationData = $ConfigurationData
    }

    & $configurationName @configurationParameters

    $startDscConfigurationParameters["Path"] = $OutputPath

    Start-DscConfiguration @startDscConfigurationParameters
    Invoke-TestCleanup
}