<#
Describe "Theirs what? | Ours what?" {
    Context "NewBase: theirs => User Decision: use theirs" {
    }
    Context "NewBase: theirs => User Decision: use ours" {
    }
    Context "NewBase: ours => User Decision: use theirs" {
    }
    Context "NewBase: ours => User Decision: use ours" {
    }
}
#>

BeforeAll {
    function Get-TestResourcePath {
        param(
            [Parameter(Mandatory=$true, Position=1)]
            [string]$fileName
        )
        $testResourcePath = Join-Path (Split-Path -parent $PSScriptRoot) "\test\Resources\$fileName"
        return $testResourcePath
    }
    function Get-TransUnitElements{
        param(
            [Parameter(Mandatory=$true, Position=1)]
            [string]$path
        )
        [xml]$xlfDocument = Get-Content $path -Raw -Encoding utf8
        $xmlElementsTransUnits = $xlfDocument.xliff.file.body.group.SelectNodes("*")
        return $xmlElementsTransUnits
    }  
    
    function New-TestEnvironment{
        param(
            [Parameter(Mandatory=$true, Position)]
            [string]$path
        )
        $mergeXlfDocumentsScript = Join-Path (Split-Path -parent $PSScriptRoot) "\src\Merge-XlfDocuments.ps1"   
        $removePreviousResult = Join-Path (Split-Path -parent $PSScriptRoot) "\test\Resources\Test.de-DE.xlf.MERGED.testresult"         
        Remove-Item -Path (Get-TestResourcePath $removePreviousResult -ErrorAction SilentlyContinue) -Force -ErrorAction SilentlyContinue       
        return $mergeXlfDocumentsScript
    }
}

Describe "Testing automerge behavior" {
    Context "When our and their target-Element contains just whitespaces" {
        It "Should be merged automatically when our state is 'translated' and theirs is 'needs-review-translation' choosing our with state 'translated'" { 
            $folderPath = 'Check-Xliff-Automerge-Whitespace'           
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -NewDocumentBasedOn Theirs

            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")                
            $xmlElementsTransUnits[4].id | Should -BeExactly "ID5"	
            $xmlElementsTransUnits[4].target.InnerText | Should -BeExactly "  "  
            $xmlElementsTransUnits[4].target.state | Should -BeExactly "translated"  
            $xmlElementsTransUnits[5].id | Should -BeExactly "ID6"	
            $xmlElementsTransUnits[5].target.InnerText | Should -BeExactly " "        
            $xmlElementsTransUnits[5].target.state | Should -BeExactly "translated"    
        }     

        It "Should be merged automatically when our target state is 'needs-review-translation' and other is 'translated' choosing theirs with state 'translated'" { 
            $folderPath = 'Check-Xliff-Automerge-Whitespace-Reverse'
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -NewDocumentBasedOn Theirs

            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits[4].id | Should -BeExactly "ID5"	
            $xmlElementsTransUnits[4].target.InnerText | Should -BeExactly "  "  
            $xmlElementsTransUnits[4].target.state | Should -BeExactly "translated"  
            $xmlElementsTransUnits[5].id | Should -BeExactly "ID6"	
            $xmlElementsTransUnits[5].target.InnerText | Should -BeExactly " "        
            $xmlElementsTransUnits[5].target.state | Should -BeExactly "translated"    
        }     
    }
}

Describe "Real world bugs test" {
    Context "Merge with conflict and blank line with diff color change" {
        It "should run without sucessfull without exceptions" { 
            $folderPath = 'Check-Xliff-Merge-With-Blank-Line'           
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 0            
        }     
    }

    Context "Validation check failed" {
        It "should detect double id" {            
            $folderPath = 'Check-Xliff-IdDoubleBug1'
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath           
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 2            
        }     
    }

    Context "Whitespaces removed" {
        It "should not remove whites spaces" {             
            $folderPath = 'Check-Xliff-WhitespaceHandling'
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath           
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

                $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
                $xmlElementsTransUnits.Count | Should -Be 4                
                $xmlElementsTransUnits[0].id | Should -BeExactly "ID1Remote"	
                $xmlElementsTransUnits[0].source.InnerText | Should -BeExactly "  "
                $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "  "
                $xmlElementsTransUnits[1].id | Should -BeExactly "ID2Remote"	
                $xmlElementsTransUnits[1].source.InnerText | Should -BeExactly "    "
                $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "    "                                          
                $xmlElementsTransUnits[3].id | Should -BeExactly "ID2Local"	
                $xmlElementsTransUnits[3].source.InnerText | Should -BeExactly " "
                $xmlElementsTransUnits[3].target.InnerText | Should -BeExactly " "                
                $xmlElementsTransUnits[2].id | Should -BeExactly "ID1Local"	
                #$xmlElementsTransUnits[2].source.InnerText | Should -BeExactly ""
                $xmlElementsTransUnits[2].target.InnerText | Should -BeExactly ""
        }     
    }
}

Describe "Interactive test" {
    Context "choose always theirs" {
        It "should select always theirs" { 
            Mock Read-Host {return "at"}  # (a)lways (t)heirs
           
            $folderPath = 'ChooseInteractiveAlwaysTheirs'
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath           
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode Interactive `
                -NewDocumentBasedOn Theirs

                $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
                $xmlElementsTransUnits.Count | Should -Be 9
                $xmlElementsTransUnits[0].id | Should -BeExactly "IDREMOTE1"	
                $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "TranslationRemote1"	                        
                $xmlElementsTransUnits[1].id | Should -BeExactly "ID3"	
                $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation3"	
                $xmlElementsTransUnits[2].id | Should -BeExactly "IDREMOTE2"	
                $xmlElementsTransUnits[2].target.InnerText | Should -BeExactly "TranslationRemote2"
                $xmlElementsTransUnits[3].id | Should -BeExactly "ID4"	
                $xmlElementsTransUnits[3].target.InnerText | Should -BeExactly "Translation4"
                $xmlElementsTransUnits[4].id | Should -BeExactly "ID5"	
                $xmlElementsTransUnits[4].target.InnerText | Should -BeExactly "Translation5RemoteModified"
                $xmlElementsTransUnits[5].id | Should -BeExactly "ID9"	
                $xmlElementsTransUnits[5].target.InnerText | Should -BeExactly "Translation9"
                $xmlElementsTransUnits[6].id | Should -BeExactly "IDREMOTE3"	
                $xmlElementsTransUnits[6].target.InnerText | Should -BeExactly "TranslationRemote3"            
                $xmlElementsTransUnits[7].id | Should -BeExactly "ID10"	
                $xmlElementsTransUnits[7].target.InnerText | Should -BeExactly "Translation10"  
                $xmlElementsTransUnits[8].id | Should -BeExactly "IDLOCAL7"	
                $xmlElementsTransUnits[8].target.InnerText | Should -BeExactly "TranslationLocal7"          
        }     
    }
}

Describe "XLF Document Validation" {
    Context "transunits check" {
        It "should detect missing id" {             
            $folderPath = 'Check-Xliff-IdMissing'
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs
            $LASTEXITCODE | Should -Be 2            
        }

        It "should detect missing id value" { 
            $folderPath = 'Check-Xliff-IdValue'            
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 2            
        }

        It "should detect multiple usage of an id" { 
            $folderPath = 'Check-Xliff-IdMultiple'            
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath           
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 2            
        }

        It "should detect missing source tag" {             
            $folderPath = 'Check-Xliff-SourceTagMissing' 
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                            
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs
            $LASTEXITCODE | Should -Be 2            
        }

         It "should not detect missing source tag of source tag just empty" { 
            $folderPath = 'Check-Xliff-SourceEmptyButNotMissing'             
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                            
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 0            
        }

        It "should detect multiple source tags" { 
            $folderPath = 'Check-Xliff-MultipleSourceTags'             
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath           
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 2            
        }

        It "should detect missing target tag" { 
            $folderPath = 'Check-Xliff-TargetTagMissing'             
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath             
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 2            
        }

        It "should detect multiple target tags" { 
            $folderPath = 'Check-Xliff-MultipleTargetTags'             
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath             
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 2            
        }

        It "should detect wrong target state" { 
            $folderPath = 'Check-Xliff-WrongTargetState'    
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath             
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $LASTEXITCODE | Should -Be 2            
        }
    }
}

Describe "Big files without conflicts" {
    Context "NewBase: theirs => User Decision: use theirs" {
        It "Should respect the order of new base document" { 
            $folderPath = 'Complex-Big'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath              
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs

            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath 'Complex-Big\Test.de-DE.xlf.MERGED.testresult')
            $xmlElementsTransUnits.Count | Should -Be 50500
            $xmlElementsNewBaseAdd = $xmlElementsTransUnits | Where-Object {$_.id.StartsWith("ID-AAAAAAAAAAAAARemote")} 
            $xmlElementsNewBaseAdd.Count | Should -Be 2000
            $xmlElementsLocalAdd = $xmlElementsTransUnits | Where-Object {$_.id.StartsWith("ID-AAAAAAAAAAAAALocal")} 
            $xmlElementsLocalAdd.Count | Should -Be 500
        }
    }
}

Describe "Complex modification at boths sides without conflict" {
    Context "NewBase: theirs => User Decision: use theirs" {
        It "Should respect the order of new base document" {   
            $folderPath = 'Complex'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                          
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 9
            $xmlElementsTransUnits[0].id | Should -BeExactly "IDREMOTE1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "TranslationRemote1"	                        
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID3"	
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation3"	
            $xmlElementsTransUnits[2].id | Should -BeExactly "IDREMOTE2"	
            $xmlElementsTransUnits[2].target.InnerText | Should -BeExactly "TranslationRemote2"
            $xmlElementsTransUnits[3].id | Should -BeExactly "ID4"	
            $xmlElementsTransUnits[3].target.InnerText | Should -BeExactly "Translation4"
            $xmlElementsTransUnits[4].id | Should -BeExactly "ID5"	
            $xmlElementsTransUnits[4].target.InnerText | Should -BeExactly "Translation5RemoteModified"
            $xmlElementsTransUnits[5].id | Should -BeExactly "ID9"	
            $xmlElementsTransUnits[5].target.InnerText | Should -BeExactly "Translation9"
            $xmlElementsTransUnits[6].id | Should -BeExactly "IDREMOTE3"	
            $xmlElementsTransUnits[6].target.InnerText | Should -BeExactly "TranslationRemote3"            
            $xmlElementsTransUnits[7].id | Should -BeExactly "ID10"	
            $xmlElementsTransUnits[7].target.InnerText | Should -BeExactly "Translation10"  
            $xmlElementsTransUnits[8].id | Should -BeExactly "IDLOCAL7"	
            $xmlElementsTransUnits[8].target.InnerText | Should -BeExactly "TranslationLocal7"
        }
    }

    Context "NewBase: Ours => User Decision: use ours" {
        It "Should respect the order of new base document" { 
            $folderPath = 'Complex'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                                                  
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 9	                        
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID3"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation3"
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID4"	
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation4"
            $xmlElementsTransUnits[2].id | Should -BeExactly "ID5"	
            $xmlElementsTransUnits[2].target.InnerText | Should -BeExactly "Translation5RemoteModified"
            $xmlElementsTransUnits[3].id | Should -BeExactly "IDLOCAL7"	
            $xmlElementsTransUnits[3].target.InnerText | Should -BeExactly "TranslationLocal7"
            $xmlElementsTransUnits[4].id | Should -BeExactly "ID9"	
            $xmlElementsTransUnits[4].target.InnerText | Should -BeExactly "Translation9"            
            $xmlElementsTransUnits[5].id | Should -BeExactly "ID10"	
            $xmlElementsTransUnits[5].target.InnerText | Should -BeExactly "Translation10"  
            $xmlElementsTransUnits[6].id | Should -BeExactly "IDREMOTE1"	
            $xmlElementsTransUnits[6].target.InnerText | Should -BeExactly "TranslationRemote1"
            $xmlElementsTransUnits[7].id | Should -BeExactly "IDREMOTE2"	
            $xmlElementsTransUnits[7].target.InnerText | Should -BeExactly "TranslationRemote2"
            $xmlElementsTransUnits[8].id | Should -BeExactly "IDREMOTE3"	
            $xmlElementsTransUnits[8].target.InnerText | Should -BeExactly "TranslationRemote3"
        
        }
    }
}

Describe "Theirs removed | Ours removed" {
    Context "NewBase: theirs => User Decision: use theirs" {
        It "Transunits Count=2, Transunit[0].Id = 'ID1', Transunit[0].Text = 'Translation1', Transunit[1].Id = 'ID2', Transunit[1].Text = 'Translation2RemoteModified'" {   
            $folderPath = 'Conflict-RemoteRemovedLocalRemoved'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath             
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	                        
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"	
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2RemoteModified"	                        
        }
    }
    Context "NewBase: theirs => User Decision: use ours" {
        It "Transunits Count=2, Transunit[0].Id = 'ID1', Transunit[0].Text = 'Translation1', Transunit[1].Id = 'ID3', Transunit[1].Text = 'Translation3LocalModified'" {   
            $folderPath = 'Conflict-RemoteRemovedLocalRemoved'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                         
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID3"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation3LocalModified"	
        }
    }
    Context "NewBase: ours => User Decision: use theirs" {
        It "Transunits Count=2, Transunit[0].Id = 'ID1', Transunit[0].Text = 'Translation1', Transunit[1].Id = 'ID2', Transunit[1].Text = 'Translation2RemoteModified'" {            
            $folderPath = 'Conflict-RemoteRemovedLocalRemoved'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                                     
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	                        
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"	
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2RemoteModified"      
        }
    }
    Context "NewBase: ours => User Decision: use ours" {
        It "Transunits Count=2, Transunit[0].Id = 'ID1', Transunit[0].Text = 'Translation1', Transunit[1].Id = 'ID3', Transunit[1].Text = 'Translation3LocalModified'" {   
            $folderPath = 'Conflict-RemoteRemovedLocalRemoved'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                                                 
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID3"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation3LocalModified"	
        }
    }
}

Describe "Theirs added | Ours added (Conflict)" {
    Context "NewBase: theirs => User Decision: use theirs" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2RemoteModified'" {               
            $folderPath = 'Conflict-RemoteAddedLocalAdded'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                                                
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2 
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2RemoteModified"	
        }
    }

    Context "NewBase: theirs => User Decision: use ours" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2LocalModified'" {               
            $folderPath = 'Conflict-RemoteAddedLocalAdded'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                                                
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2LocalModified"	
        }
    }

    Context "NewBase: ours => User Decision: use theirs" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2RemoteModified'" {                           
            $folderPath = 'Conflict-RemoteAddedLocalAdded'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                       
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2RemoteModified"	
        }
    }

    Context "NewBase: ours => User Decision: use ours" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2LocalModified'" {                         
            $folderPath = 'Conflict-RemoteAddedLocalAdded'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath  
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2LocalModified"	
        }
    }
}

Describe "Theirs removed | Ours modified (Conflict)" {
    Context "NewBase: theirs => User Decision: use theirs" {
        It "Transunits Count=1, Transunit[0].Id = 'ID1', Transunit[0].Text = 'Translation1'" {             
            $folderPath = 'Conflict-RemoteRemovedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath  
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            if ($xmlElementsTransUnits -is [Array]){
                $xmlElementsTransUnits.Count | Should -Be 1            
            }
            $xmlElementsTransUnits.id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits.target.InnerText | Should -BeExactly "Translation1"	                        
        }
    }
    Context "NewBase: theirs => User Decision: use ours" {
        It "Transunits Count=2, Transunit[0].Id = 'ID1', Transunit[0].Text = 'Translation1', Transunit[1].Id = 'ID2', Transunit[1].Text = 'Translation2LocalModified'" {              
            $folderPath = 'Conflict-RemoteRemovedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath  
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2  
            if ($xmlElementsTransUnits -is [Array]){
                $xmlElementsTransUnits.Count | Should -Be 2
            }                      
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2LocalModified"	
        }
    }
    Context "NewBase: ours => User Decision: use theirs" {
        It "Transunits Count=1, Transunit[0].Id = 'ID1', Transunit[0].Text = 'Translation1'" {                           
            $folderPath = 'Conflict-RemoteRemovedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath  
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            if ($xmlElementsTransUnits -is [Array]){
                $xmlElementsTransUnits.Count | Should -Be 1            
            }            
            $xmlElementsTransUnits.id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits.target.InnerText | Should -BeExactly "Translation1"	            
        }
    }
    Context "NewBase: ours => User Decision: use ours" {
        It "Transunits Count=2, Transunit[0].Id = 'ID1', Transunit[0].Text = 'Translation1', Transunit[1].Id = 'ID2', Transunit[1].Text = 'Translation2LocalModified'" {             
            $folderPath = 'Conflict-RemoteRemovedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath  
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2LocalModified"	
        }
    }
}

Describe "Theirs modified | Ours modified (Conflict)" {
    Context "NewBase: theirs => User Decision: use theirs" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2RemoteModified'" {                          
            $folderPath = 'Conflict-RemoteModifiedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath 
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2RemoteModified"	
        }
    }

    Context "NewBase: theirs => User Decision: use ours" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2LocalModified'" {              
            $folderPath = 'Conflict-RemoteModifiedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath             
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2LocalModified"	
        }
    }

    Context "NewBase: ours => User Decision: use theirs" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2RemoteModified'" {             
            $folderPath = 'Conflict-RemoteModifiedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                         
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2RemoteModified"	
        }
    }

    Context "NewBase: ours => User Decision: use ours" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2LocalModified'" {              
            $folderPath = 'Conflict-RemoteModifiedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath             
            &$MergeXlfDocumentsScript `
            -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
            -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
            -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2LocalModified"	
        }
    }
}

Describe "Theirs modified | Ours removed (Conflict)" {
    Context "NewBase: theirs => User Decision: use theirs" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2RemoteModified'" {            
            $folderPath = 'Conflict-RemoteModifiedLocalModified'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                         
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2RemoteModified"	
        }       
    }

    Context "NewBase: theirs => User Decision: use ours" {
        It "Transunits Count=1, Id[0] = 'ID1', Target-Text[0] = 'Translation1'" {     
            $folderPath = 'Conflict-RemoteModifiedLocalRemoved'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                                              
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Theirs
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            if ($xmlElementsTransUnits -is [Array]){
                $xmlElementsTransUnits.Count | Should -Be 1           
            }
            $xmlElementsTransUnits.id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits.target.InnerText | Should -BeExactly "Translation1"	
        }       
    }

    Context "NewBase: ours => User Decision: use theirs" {
        It "Transunits Count=2, Id[0] = 'ID1', Target-Text[0] = 'Translation1', Id[1] = 'ID2', Target-Text[1] = 'Translation2RemoteModified'" {                         
            $folderPath = 'Conflict-RemoteModifiedLocalRemoved'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                                                          
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysTheirs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            $xmlElementsTransUnits.Count | Should -Be 2            
            $xmlElementsTransUnits[0].id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits[0].target.InnerText | Should -BeExactly "Translation1"	
            $xmlElementsTransUnits[1].id | Should -BeExactly "ID2"
            $xmlElementsTransUnits[1].target.InnerText | Should -BeExactly "Translation2RemoteModified"	
        }       
    }

    Context "NewBase: ours => User Decision: use ours" {
        It "Transunits Count=1, Id[0] = 'ID1', Target-Text[0] = 'Translation1'" {       
            $folderPath = 'Conflict-RemoteModifiedLocalRemoved'  
            $MergeXlfDocumentsScript = New-TestEnvironment $folderPath                                 
            &$MergeXlfDocumentsScript `
                -BaseFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.BASE.test") `
                -OurFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.LOCAL.test") `
                -TheirFile (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.REMOTE.test") `
                -ConflictHandlingMode UseAlwaysOurs `
                -NewDocumentBasedOn Ours
            $xmlElementsTransUnits = Get-TransUnitElements (Get-TestResourcePath "$folderPath\Test.de-DE.xlf.MERGED.testresult")
            if ($xmlElementsTransUnits -is [Array]){
                $xmlElementsTransUnits.Count | Should -Be 1           
            }
            $xmlElementsTransUnits.id | Should -BeExactly "ID1"	
            $xmlElementsTransUnits.target.InnerText | Should -BeExactly "Translation1"	
        }       
    }
}