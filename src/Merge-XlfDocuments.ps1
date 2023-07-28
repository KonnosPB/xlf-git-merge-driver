<#PSScriptInfo

.VERSION 0.3.4.0

.GUID e88958ff-827a-4529-900a-9b5b3303d190

.AUTHOR Konstantinos Papoulas-Brosch

.COPYRIGHT Konstantinos Papoulas-Brosch

.TAGS GIT, XLF, XLIFF, MERGE

.LICENSEURI https://github.com/KonnosPB/xlf-git-merge-driver/blob/main/LICENSE.txt

.PROJECTURI https://github.com/KonnosPB/xlf-git-merge-driver

#>
<#
.SYNOPSIS
Merges XLF-Documents in an git scenarios. 
  
.DESCRIPTION

Merges XLF-Documents in an git environment. You must integrate the script in the ./.git/config file like this.
[merge "xlf-merge-driver"]
	name = A custom merge driver written in powershell used to resolve conflicts of xlf translation files
	driver = powershell.exe -File '../xlf-git-merge-driver/src/Merge-XlfDocuments.ps1' %O %A %B %P

and add following content to the ./.gitattributes files
*.xlf merge=xlf-merge-driver

.PARAMETER BaseFile
The file path of the merge ancestor’s version

.PARAMETER OurFile
The file path of the current version. (ours/yours version)

.PARAMETER TheirFile
The file path of the other branches' version. (ours/yours version)

.PARAMETER FileName
The name of the file which is currently merged.

.PARAMETER ConflictHandlingMode
Determines what should happen in conflict cases
Interactive     => Ask user
Abort           => Always abort with exit code 1
UseAlwaysTheirs => Select always theirs. (Useful in test environments)
UseAlwaysOurs   => Select always ours. (Useful in test environments)

.PARAMETER NewLineCharacters
Default value is "`r`n"

.PARAMETER XmlIndentation
Indentation of the xml output. Default value is 2.

.PARAMETER Version
Outputs the current version

.INPUTS
None. You cannot pipe objects to Merge-XlfDocuments.

.OUTPUTS
None. You cannot pipe objects to Merge-XlfDocuments
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string] $BaseFile,
    [Parameter(Mandatory, Position = 1)]
    [string] $OurFile,
    [Parameter(Mandatory, Position = 2)]
    [string] $TheirFile,
    [Parameter(Position = 3)]
    [string] $FileName,
    [Parameter()]
    [ValidateSet("Interactive", "Abort", "UseAlwaysTheirs", "UseAlwaysOurs")]
    [string] $ConflictHandlingMode = "Interactive",
    [Parameter()]
    [ValidateSet("Theirs", "Ours")]
    [string] $NewDocumentBasedOn = "Theirs",    
    [Parameter()]    
    [string] $NewLineCharacters = "`r`n",
    [Parameter()]    
    [ValidateRange(0, 16)]
    [int] $XmlIndentation = 2,
    [Parameter()]    
    [ValidateSet("Both", "Theirs", "Ours", "NoCheck")]
    [string] $CheckDocument = "Both"
)
# Variables
$currVersion = '0.3.4.0'
$newDocumentBasedOnOurs = $false
if ($NewDocumentBasedOn -eq 'Ours') {
    $newDocumentBasedOnOurs = $true
}
$newDocumentBasedOn = "Theirs"
$otherFileBasedOn = "Ours"
$newBaseFile = $TheirFile
$otherFile = $OurFile
if ($newDocumentBasedOnOurs) {
    $newBaseFile = $OurFile
    $otherFile = $TheirFile
    $newDocumentBasedOn = "Ours"
    $otherFileBasedOn = "Theirs"
}
$baseIdTransUnitHashtable = [ordered]@{}    # Mapping of Id and TransUnit XmlElement
$otherIdTransUnitHashtable = [PSCustomObject]@{    # Collection of differences between other and base   
    AddedTransUnitIdMapping    = [ordered]@{}
    ModifiedTransUnitIdMapping = [ordered]@{}
    RemovedTransUnitIdMapping  = [ordered]@{}
}
$newBaseIdTransUnitHashtable = [PSCustomObject]@{    # Collection of differences between newBase and base
    AddedTransUnitIdMapping    = [ordered]@{}
    ModifiedTransUnitIdMapping = [ordered]@{}
    RemovedTransUnitIdMapping  = [ordered]@{}
}
$conflictExitCode = 1    
enum ConfictHandling {
    Abort
    Other
    NewBase
}


function New-XlfDocument {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path,
        [Parameter(Mandatory, Position = 1)]
        [ValidateSet("Theirs", "Ours", "Base")]
        [string] $CurrentDocumentSource
    )   
    [xml] $xlfDocument = [System.Xml.XmlDocument]::new()        
    try {
        $content = Get-Content $Path -Raw -Encoding utf8    
        $content = $content -replace "(`t|`r|`n)", ""
        $content = $content -replace ">[\s`r`n]*<", "><"    
    
        $xlfDocument.PreserveWhitespace = $false
        $xlfDocument.LoadXml($content)         
    }
    catch {
        Write-Error "$CurrentDocumentSource XLF Document is not a valid XML-File. Details`r`n$_"
        exit(1) 
    }    
    return $xlfDocument
}


function New-IdTransUnitHashtable {
    param(
        [Parameter(Mandatory, Position = 0)]
        [xml]$XlfDocument,
        [Parameter(Mandatory, Position = 1)]
        $XmlElementsTransUnits,
        [Parameter(Mandatory, Position = 2)]
        [ValidateSet("Theirs", "Ours", "Base")]
        [string] $CurrentDocumentSource
    )   
    
    $errExitCode = 2
    $xliffFile = $XlfDocument.xliff.file    
    $errorOccured = $false   # Collect all messages and exit at the end if check fails.    
    $resultIdHashtable = [ordered]@{}
    $XmlElementsTransUnits | ForEach-Object {
        $xmlElementsTransUnit = $_
        $skipThisTransUnit = $false
        
        if ($CheckDocument){                         
            if (-not $xmlElementsTransUnit.id){
                Write-Error "($CurrentDocumentSource document) trans-unit id attribute missing`r`n$($xmlElementsTransUnit.OuterXml)"
                $skipThisTransUnit = $true
                $errorOccured = $true
            } else{
                if ([string]::IsNullOrWhiteSpace($xmlElementsTransUnit.id)){
                    Write-Error "($CurrentDocumentSource document) trans-unit id attribute value is empty`r`n$($xmlElementsTransUnit.OuterXml)"
                    $skipThisTransUnit = $true
                    $errorOccured = $true
                } else {
                    if ($resultIdHashtable.Contains($xmlElementsTransUnit.id)){
                        Write-Error "($CurrentDocumentSource document) trans-unit id '$($xmlElementsTransUnit.id)' used several times"
                        $skipThisTransUnit = $true
                        $errorOccured = $true
                    }
                }
            }          
    
            if ($null -eq $xmlElementsTransUnit.source){
                Write-Error "($CurrentDocumentSource document) <source> xml-tag missing in trans-unit element with id '$($xmlElementsTransUnit.id)'"
                $skipThisTransUnit = $true
                $errorOccured = $true
            }
    
            if ($xmlElementsTransUnit.source.Count -gt 1){
                Write-Error "($CurrentDocumentSource document) <source> xml-tag used multiple times in trans-unit element with id '$($xmlElementsTransUnit.id)'"
                $skipThisTransUnit = $true
                $errorOccured = $true
            }
                
            if ($xliffFile.Attributes["source-language"].Value -ne $xliffFile.Attributes["target-language"].Value)
            {
                if ($null -eq $xmlElementsTransUnit.target){
                    Write-Error "($CurrentDocumentSource document) <target> xml-tag missing in trans-unit element with id '$($xmlElementsTransUnit.id)'"
                    $skipThisTransUnit = $true
                    $errorOccured = $true
                }
                
                if ($xmlElementsTransUnit.target.Count -gt 1){
                    Write-Error "($CurrentDocumentSource document) <target> xml-tag used multiple times in trans-unit element with id '$($xmlElementsTransUnit.id)'"
                    $skipThisTransUnit = $true
                    $errorOccured = $true
                }
                
                if (-not ($xmlElementsTransUnit.target.state -In @('translated', 'new', 'needs-review-translation', 'final'))){
                    Write-Error "($CurrentDocumentSource document) target state attribute has not the value 'translated', 'new', 'needs-review-translation' or 'final' in trans-unit element with id '$($xmlElementsTransUnit.id)'"
                    $skipThisTransUnit = $true
                    $errorOccured = $true
                }
            }                   
        } # if ($CheckDocument){   

        if (-not $skipThisTransUnit){
            $resultIdHashtable.add($xmlElementsTransUnit.id, $xmlElementsTransUnit);
        }
    }
    if ($errorOccured){
        exit($errExitCode)     
    }
    return $resultIdHashtable
}

function New-IdTransUnitHashtableByXmlDocument { 
    param(
        [Parameter(Mandatory, Position = 0)]
        [xml]$XlfDocument,
        [Parameter(Mandatory, Position = 1)]
        [ValidateSet("Theirs", "Ours", "Base")]
        [string] $CurrentDocumentSource
    )   
    $xmlElementsTransUnits = $XlfDocument.xliff.file.body.group.SelectNodes("*")
    $idTransUnits = New-IdTransUnitHashtable $XlfDocument $xmlElementsTransUnits $CurrentDocumentSource
    return $idTransUnits
}

function New-IdTransUnitHashtableByXmlDocumentFromFile { 
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,
        [Parameter(Mandatory, Position = 1)]
        [ValidateSet("Theirs", "Ours", "Base")]
        [string] $CurrentDocumentSource
    )      
    [xml]$xlfDocument = New-XlfDocument $Path $CurrentDocumentSource
    $idTransUnits = New-IdTransUnitHashtableByXmlDocument $xlfDocument $CurrentDocumentSource
    return $idTransUnits
}

function Get-Diffs {
    param(
        [Parameter(Mandatory, Position = 1)]
        $IdTransUnitHashtable
    )
    $addedTransUnitIdMapping = [ordered]@{}
    $modifiedTransUnitIdMapping = [ordered]@{}
    $removedTransUnitIdMapping = [ordered]@{}
    $IdTransUnitHashtable.GetEnumerator() | ForEach-Object {
        $compareIdTransUnitPair = $_
        $currentId = $compareIdTransUnitPair.Name
        $xmlCompareTransUnitElement = $compareIdTransUnitPair.Value
        $xmlBaseTransUnitElement = $baseIdTransUnitHashtable[$currentId]                               
        if ($xmlBaseTransUnitElement) {            
            $compareItemHashCode = $xmlCompareTransUnitElement.OuterXml.GetHashCode()   
            $baseItemHashCode = $xmlBaseTransUnitElement.OuterXml.GetHashCode() 
            if ($compareItemHashCode -ne $baseItemHashCode) {
                # Compared to base the TransUnit element has been modified
                $modifiedTransUnitIdMapping.Add($currentId, $xmlCompareTransUnitElement)
            }
        }
        else {
            # Base has no element with this id. So the transunit element has been newly added.
            $addedTransUnitIdMapping.Add($currentId, $xmlCompareTransUnitElement)
        }
    }

    $baseIdTransUnitHashtable.GetEnumerator() | ForEach-Object {
        $baseIdTransUnitPair = $_
        $currentId = $baseIdTransUnitPair.Name       
        $compareIdTransUnitPair = $IdTransUnitHashtable[$currentId]                
        if (-not $compareIdTransUnitPair) { 
            # No element found with this ID. So the element has been removed.        
            $removedTransUnitIdMapping.Add($currentId, $baseIdTransUnitPair.Value)
        }
    }

    return [PSCustomObject]@{
        AddedHashTable    = $addedTransUnitIdMapping
        ModifiedHashTable = $modifiedTransUnitIdMapping
        RemovedHashTable  = $removedTransUnitIdMapping
    }
}

function Get-TransUnitPrettyPrint {
    param(
        [Parameter(Mandatory, Position = 0)]
        $XmlTransUnitElement,
        [Parameter(Mandatory, Position = 1)]
        [ValidateSet('added', 'modified', 'removed')]
        [string] $ModificationType
    )

    $stringWriter = [System.IO.StringWriter]::new()
    $xmlSettings = [System.Xml.XmlWriterSettings]::new()    
    if ($XmlIndentation -gt 0) {
        $xmlSettings.Indent = $true
        $xmlSettings.IndentChars = "".PadLeft($XmlIndentation, " ")
    }
    $xmlSettings.ConformanceLevel = [System.Xml.ConformanceLevel]::Auto
    $xmlSettings.NewLineChars = $NewLineCharacters
    $xmlWriter = [System.Xml.XmlWriter]::Create($stringWriter, $xmlSettings)   
    $XmlTransUnitElement.WriteTo($xmlWriter) 
    $xmlWriter.Flush()
    $stringWriter.Flush()     
    $out = $stringWriter.ToString()       

    $xmlDisplay = ''
    $outerXml = $out.Split("`n")
    $linePrefix = "+"
    if ($ModificationType -eq 'modified') {
        $linePrefix = "~"
    }
    elseif ($ModificationType -eq 'removed') {
        $linePrefix = "-"
    }
    for ($i = 0; $i -lt $outerXml.Count; $i++) {
        $outerXmlLine = $outerXml[$i].Trim()
        $indentationWhitespaces = "".PadLeft($XmlIndentation, " ")
        $xmlDisplay += $linePrefix
        if (($i -gt 0) -and ($i -lt $outerXml.Count - 1)) {
            $indentationWhitespaces += "".PadLeft($XmlIndentation * 2, " ")
        }                       
        $xmlDisplay += $indentationWhitespaces
        $xmlDisplay += $outerXmlLine
        if ($i -lt $outerXml.Count - 1) {            
            $xmlDisplay += $NewLineCharacters             
        }
    }
    return $xmlDisplay
}

function Confirm-Handling {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $CurrentId,
        [Parameter(Mandatory, Position = 1)]
        $XmlNewBaseTransUnitElement,
        [Parameter(Mandatory, Position = 2)]
        [ValidateSet('added', 'modified', 'removed')]
        [string]$NewBaseModificationType,
        [Parameter(Mandatory, Position = 3)]
        $XmlOtherTransUnitElement,
        [Parameter(Mandatory, Position = 4)]
        [ValidateSet('added', 'modified', 'removed')]
        [string]$OtherModificationType
    )   
    if ($script:ConflictHandlingMode -eq 'Abort') {
        return [ConfictHandling]::Abort
    }

    [string] $newBaseXmlDisplay = Get-TransUnitPrettyPrint $XmlNewBaseTransUnitElement $NewBaseModificationType
    [string] $otherXmlDisplay = Get-TransUnitPrettyPrint $XmlOtherTransUnitElement $OtherModificationType
    $completeUserMessage = "Conflict at trans-unit '$CurrentId'. $NewLineCharacters<<<<<<< ours:$FileName $OtherModificationType$NewLineCharacters$otherXmlDisplay$NewLineCharacters=======$NewLineCharacters$newBaseXmlDisplay$NewLineCharacters>>>>>>> theirs:$FileName $NewBaseModificationType$NewLineCharacters$($NewLineCharacters)Select ... and press enter`r`n(t)heirs`r`n(o)urs`r`n(at) always theirs`r`n(ao) always ours`r`n(c)ancel`r`n>"
    if ($newDocumentBasedOnOurs) {
        $completeUserMessage = "Conflict at trans-unit '$CurrentId'. $NewLineCharacters<<<<<<< ours:$FileName $NewBaseModificationType$NewLineCharacters$newBaseXmlDisplay$NewLineCharacters=======$NewLineCharacters$otherXmlDisplay$NewLineCharacters>>>>>>> theirs:$FileName $OtherModificationType$NewLineCharacters$($NewLineCharacters)Select ... and press enter`r`n(t)heirs`r`n(o)urs`r`n(at) always theirs`r`n(ao) always ours`r`n(c)ancel`r`n>"
    }      
    
    Write-Host "Conflict handling mode $script:ConflictHandlingMode"
    $result = ""
    if ($script:ConflictHandlingMode -eq 'UseAlwaysTheirs') {
        $result = "t" #theirs
    }
    elseif ($script:ConflictHandlingMode -eq 'UseAlwaysOurs') {
        $result = "o" #ours
    }
    else {
        $result = Read-Host $completeUserMessage
        $result = $result.ToLower().TrimStart()
        Write-Host "Entered '$result'"
        if ($result -eq 'at') {
            $result = "t" #theirs
            $script:ConflictHandlingMode = 'UseAlwaysTheirs'
        }
        elseif ($result -eq 'ao') {        
            $result = "o" #ours
            $script:ConflictHandlingMode = 'UseAlwaysOurs'
        }
    }

    if ($result -eq "t") {
        if ($newDocumentBasedOnOurs) {
            return [ConfictHandling]::Other
        }
        else {
            return [ConfictHandling]::NewBase
        }
    }
    if ($result -eq "o") {
        if ($newDocumentBasedOnOurs) {
            return [ConfictHandling]::NewBase
        }
        else {
            return [ConfictHandling]::Other
        }
    }    
    return [ConfictHandling]::Abort
}

function Add-TransUnitAtEnd {
    param(
        [Parameter(Mandatory, Position = 0)]
        [xml] $XlfDocument,
        [Parameter(Mandatory, Position = 1)]
        $XmlTransUnitToAddElement
    )    
    [System.Xml.XmlElement]$group = $XlfDocument.GetElementsByTagName("group") | Select-Object -First 1
    $xmlImportedTransUnitToAddElement = $XlfDocument.ImportNode($xmlTransUnitToAddElement, $true <#deep#>)
    $XmlTransUnitToAddElement = $xmlImportedTransUnitToAddElement
    $null = $group.AppendChild($XmlTransUnitToAddElement)
}

function Invoke-ReplaceTransUnit {
    param(
        [Parameter(Mandatory, Position = 0)]
        [xml] $XlfNewBaseDocument,
        [Parameter(Position = 1)]
        $XmlTransUnitElementToReplace,
        [Parameter(Mandatory, Position = 2)]
        $XmlTransUnitElementReplacement
    )        
    [System.Xml.XmlElement]$group = $XlfNewBaseDocument.GetElementsByTagName("group") | Select-Object -First 1
    $xmlTransUnitElementReplacementImported = $XlfNewBaseDocument.ImportNode($XmlTransUnitElementReplacement, $true <#deep#>)
    if (-not $XmlTransUnitElementToReplace) {
        $XmlTransUnitElementToReplace = $newBaseIdTransUnitHashtable[$XmlTransUnitElementReplacement.id]
        if (-not $XmlTransUnitElementToReplace) {
            return
        }
    }
    $null = $group.ReplaceChild($xmlTransUnitElementReplacementImported, $XmlTransUnitElementToReplace)
}

function Remove-TransUnit {
    param(
        [Parameter(Mandatory, Position = 0)]
        [xml] $XlfNewBaseDocument,
        [Parameter(Mandatory, Position = 1)]
        $XmlTransUnitToRemoveElement
    )   
    [System.Xml.XmlElement]$group = $XlfNewBaseDocument.GetElementsByTagName("group") | Select-Object -First 1
    $currentId = $XmlTransUnitToRemoveElement.Id
    if (-not $currentId) {
        return
    }
    $elementToRemove = $newBaseIdTransUnitHashtable[$currentId]
    if (-not $elementToRemove) {
        return
    }
    $null = $group.RemoveChild($elementToRemove)
}

function Merge-XlfDocument {
    param(
        [Parameter(Mandatory, Position = 0)]
        [xml]$XlfNewBaseDocument,
        [Parameter(Mandatory, Position = 1)]
        $NewBaseDiffsHashtables,
        [Parameter(Mandatory, Position = 2)]
        $OtherDiffsHashtables
    )

    #region Cases when other is added
    $OtherDiffsHashtables.AddedHashTable.GetEnumerator() | ForEach-Object {
        $currentId = $_.Name
        $xOtherElement = $_.Value
        $isHandled = $false

        # Is newBase and other added?
        $xNewBaseElement = $NewBaseDiffsHashtables.AddedHashTable[$currentId]
        if ($xNewBaseElement) {            
            if ($xNewBaseElement.OuterXml.GetHashCode() -ne $xOtherElement.OuterXml.GetHashCode()) {                                                  
                $isHandled = $true
                $userDecision = Confirm-Handling $currentId $xNewBaseElement 'added'  $xOtherElement 'added'
                if ([ConfictHandling]::Abort -eq $userDecision) {
                    exit($conflictExitCode)
                }
                elseif ([ConfictHandling]::Other -eq $userDecision) {
                    Invoke-ReplaceTransUnit $XlfNewBaseDocument $xNewBaseElement $xOtherElement                               
                }
                elseif ([ConfictHandling]::NewBase -eq $userDecision) {
                    # Nothing to do. leave other as it is                    
                }
            }
        }

        # Is other added and newBase modified?
        $xNewBaseElement = $NewBaseDiffsHashtables.ModifiedHashTable[$currentId]
        if ($xNewBaseElement) {                        
            if ($xNewBaseElement.OuterXml.GetHashCode() -ne $xOtherElement.OuterXml.GetHashCode()) {                                                  
                $isHandled = $true
                $userDecision = Confirm-Handling $currentId $xNewBaseElement 'modified' $xOtherElement 'added'
                if ([ConfictHandling]::Abort -eq $userDecision) {
                    exit($conflictExitCode)
                }
                elseif ([ConfictHandling]::Other -eq $userDecision) {
                    Invoke-ReplaceTransUnit $XlfNewBaseDocument $xNewBaseElement $xOtherElement                                 
                }
                elseif ([ConfictHandling]::NewBase -eq $userDecision) {
                    # Nothing to do. leave other as it is                    
                }
            }
        }

        # Is other added and newBase removed?
        $xNewBaseElement = $NewBaseDiffsHashtables.RemovedHashTable[$currentId]
        if ($xNewBaseElement) {     
            $isHandled = $true                              
            $userDecision = Confirm-Handling $currentId $xNewBaseElement 'removed' $xOtherElement 'added'
            if ([ConfictHandling]::Abort -eq $userDecision) {
                exit($conflictExitCode)
            }
            elseif ([ConfictHandling]::Other -eq $userDecision) {
                Add-TransUnitAtEnd $XlfNewBaseDocument $xOtherElement                                
            }
            elseif ([ConfictHandling]::NewBase -eq $userDecision) {
                # Nothing to do. leave remote as it is                
            }            
        }     
        
        if (-not $isHandled) {
            Add-TransUnitAtEnd $XlfNewBaseDocument $xOtherElement    
        }
    } 
    #endregion Cases when other is added    
    
    #region Cases when other is modified
    $OtherDiffsHashtables.ModifiedHashTable.GetEnumerator() | ForEach-Object {
        $currentId = $_.Name
        $xOtherElement = $_.Value
        $isHandled = $false

        # Is newBase added and other modified?
        $xNewBaseElement = $NewBaseDiffsHashtables.AddedHashTable[$currentId]
        if ($xNewBaseElement) {            
            if ($xNewBaseElement.OuterXml.GetHashCode() -ne $xOtherElement.OuterXml.GetHashCode()) {                                                  
                $isHandled = $true
                $userDecision = Confirm-Handling $currentId $xNewBaseElement 'added' $xOtherElement 'modified'
                if ([ConfictHandling]::Abort -eq $userDecision) {
                    exit($conflictExitCode)
                }
                elseif ([ConfictHandling]::Other -eq $userDecision) {
                    Invoke-ReplaceTransUnit $XlfNewBaseDocument $xNewBaseElement $xOtherElement                               
                }
                elseif ([ConfictHandling]::NewBase -eq $userDecision) {
                    # Nothing to do. leave other as it is                    
                }
            }
        }

        # Is other and newBase modified?
        $xNewBaseElement = $NewBaseDiffsHashtables.ModifiedHashTable[$currentId]
        if ($xNewBaseElement) {            
            if ($xNewBaseElement.OuterXml.GetHashCode() -ne $xOtherElement.OuterXml.GetHashCode()) {                                                  
                $isHandled = $true
                $userDecision = Confirm-Handling $currentId $xNewBaseElement 'modified' $xOtherElement 'modified'
                if ([ConfictHandling]::Abort -eq $userDecision) {
                    exit($conflictExitCode)
                }
                elseif ([ConfictHandling]::Other -eq $userDecision) {
                    Invoke-ReplaceTransUnit $XlfNewBaseDocument $xNewBaseElement $xOtherElement                               
                }
                elseif ([ConfictHandling]::NewBase -eq $userDecision) {
                    # Nothing to do. leave other as it is                    
                }
            }
        }

        # Is other modified and newBase removed?
        $xNewBaseElement = $NewBaseDiffsHashtables.RemovedHashTable[$currentId]
        if ($xNewBaseElement) {                             
            $isHandled = $true
            $userDecision = Confirm-Handling $currentId $xNewBaseElement 'removed' $xOtherElement 'modified'
            if ([ConfictHandling]::Abort -eq $userDecision) {
                exit($conflictExitCode)
            }
            elseif ([ConfictHandling]::Other -eq $userDecision) {
                #Remove-TransUnit $XlfNewBaseDocument $xNewBaseElement
                Add-TransUnitAtEnd $XlfNewBaseDocument $xOtherElement                               
            }
            elseif ([ConfictHandling]::NewBase -eq $userDecision) {
                # Nothing to do. leave remote as it is                
            }            
        } 
        
        if (-not $isHandled) {
            Invoke-ReplaceTransUnit $XlfNewBaseDocument $xNewBaseElement $xOtherElement
        }
    }
    #endregion Cases when other is modified

    #region Cases when other is removed
    $OtherDiffsHashtables.RemovedHashTable.GetEnumerator() | ForEach-Object {
        $currentId = $_.Name
        $xOtherElement = $_.Value
        $isHandled = $false

        # Is other removed and newBase added
        $xNewBaseElement = $newBaseDiffsHashtables.AddedHashTable[$currentId]
        if ($xNewBaseElement) {       
            $isHandled = $true
            $userDecision = Confirm-Handling $currentId $xNewBaseElement 'added' $xOtherElement 'removed'
            if ([ConfictHandling]::Abort -eq $userDecision) {
                exit($conflictExitCode)
            }
            elseif ([ConfictHandling]::Other -eq $userDecision) {
                Remove-TransUnit $xlfNewBaseDocument $xNewBaseElement
            }
            elseif ([ConfictHandling]::NewBase -eq $userDecision) {
                # Nothing to do. leave remote as it is
            }            
        }

        # Is other removed and newBase modified
        $xNewBaseElement = $newBaseDiffsHashtables.ModifiedHashTable[$currentId]
        if ($xNewBaseElement) {    
            $isHandled = $true                  
            $userDecision = Confirm-Handling $currentId $xNewBaseElement 'modified' $xOtherElement 'removed'
            if ([ConfictHandling]::Abort -eq $userDecision) {
                exit($conflictExitCode)
            }
            elseif ([ConfictHandling]::Other -eq $userDecision) {                
                Remove-TransUnit $xlfNewBaseDocument $xNewBaseElement
            }
            elseif ([ConfictHandling]::NewBase -eq $userDecision) {
                # Nothing to do. leave remote as it is
            }            
        }

        if (-not $isHandled) {
            Remove-TransUnit $xlfNewBaseDocument $xOtherElement
        }
    }
    #endregion Cases when other is removed    
}

function Get-XmlPrettyPrint {
    param(
        [Parameter(Mandatory, Position = 0)]
        [xml] $XlfDocument
    )         
    $stringWriter = [System.IO.StringWriter]::new()
    $xmlSettings = [System.Xml.XmlWriterSettings]::new()    
    if ($XmlIndentation -gt 0) {
        $xmlSettings.Indent = $true
        $xmlSettings.IndentChars = "".PadLeft($XmlIndentation, " ")
    }
    $xmlSettings.NewLineChars = $NewLineCharacters
    $xmlWriter = [System.Xml.XmlWriter]::Create($stringWriter, $xmlSettings)   
    $XlfDocument.WriteContentTo($xmlWriter) 
    $XmlWriter.Flush()
    $stringWriter.Flush()     
    $out = $stringWriter.ToString()   
    return $out
}

function Write-Xml {
    param(
        [Parameter(Mandatory, Position = 0)]
        [xml] $XlfDocument,
        [Parameter(Mandatory, Position = 1)]
        [string] $Path
    )
    $xmlString = Get-XmlPrettyPrint $XlfDocument
    Set-Content -Pass $Path -Value $xmlString -Encoding utf8 | Out-Null
}

Write-Host "Merging $FileName with xlf-merger-driver $currVersion"

try {
       
    $baseIdTransUnitHashtable = New-IdTransUnitHashtableByXmlDocumentFromFile $BaseFile Base

    [xml]$xlfNewBaseDocument = New-XlfDocument $newBaseFile $newDocumentBasedOn
    $newBaseIdTransUnitHashtable = New-IdTransUnitHashtableByXmlDocument $xlfNewBaseDocument $newDocumentBasedOn
    $otherIdTransUnitHashtable = New-IdTransUnitHashtableByXmlDocumentFromFile $otherFile $otherFileBasedOn
    $NewBaseDiffs = Get-Diffs $newBaseIdTransUnitHashtable
    $OtherDiffs = Get-Diffs $otherIdTransUnitHashtable
    $null = Merge-XlfDocument $xlfNewBaseDocument $NewBaseDiffs $OtherDiffs
    if ($OurFile.EndsWith("LOCAL.test")) {
        $OurFile = $OurFile.Replace("LOCAL.test", "MERGED.testresult")  # Debug Reason. (normally the files ends with xlf. "LOCAL.xml" is test case)
    }
    Write-Xml $xlfNewBaseDocument $OurFile
    exit(0)
}
catch {
    Write-Error $_
    exit($conflictExitCode)
}
