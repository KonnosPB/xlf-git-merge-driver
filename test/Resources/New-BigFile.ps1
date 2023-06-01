$sbBegin = [System.Text.StringBuilder]::new()
$sbBegin.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
$sbBegin.AppendLine('<xliff version="1.2"')
$sbBegin.AppendLine('  xmlns="urn:oasis:names:tc:xliff:document:1.2"')
$sbBegin.AppendLine('  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 xliff-core-1.2-transitional.xsd">')
$sbBegin.AppendLine('  <file datatype="xml" source-language="en-US" target-language="de-DE" original="Test" tool-id="MultilingualAppToolkit" product-name="n/a" product-version="n/a" build-num="n/a">')
$sbBegin.AppendLine('    <header>')
$sbBegin.AppendLine('      <tool tool-id="MultilingualAppToolkit" tool-name="Multilingual App Toolkit" tool-version="4.0.1915.0" tool-company="Microsoft" />')
$sbBegin.AppendLine('    </header>')
$sbBegin.AppendLine('    <body>')
$sbBegin.AppendLine('      <group id="body" datatype="resx">')

$sbBase = [System.Text.StringBuilder]::new()
$sbLocal = [System.Text.StringBuilder]::new()
$sbRemote = [System.Text.StringBuilder]::new()
for($i=0; $i -lt 2000; $i++){
    $sbTransunit = [System.Text.StringBuilder]::new()
    $sbTransunit.AppendLine('        <trans-unit id="ID-AAAAAAAAAAAAARemote' + $i + '" size-unit="char" translate="yes" xml:space="preserve">')
    $sbTransunit.AppendLine("          <source>OriginalRemote$i</source>")
    $sbTransunit.AppendLine('          <target state="translated">TranslationRemote' + $i + '</target>')
    $sbTransunit.AppendLine('          <note from="Xliff Generator" annotates="general" priority="3">Table Test - Property Caption</note>')
    $sbTransunit.AppendLine('        </trans-unit>')
    $sbRemote.Append($sbTransunit)
}

for($i=0; $i -lt 50000; $i++){
    $sbTransunit = [System.Text.StringBuilder]::new()
    $sbTransunit.AppendLine('        <trans-unit id="ID-AAAAAAAAAAAAA' + $i + '" size-unit="char" translate="yes" xml:space="preserve">')
    $sbTransunit.AppendLine("          <source>Original$i</source>")
    $sbTransunit.AppendLine('          <target state="translated">Translation' + $i + '</target>')
    $sbTransunit.AppendLine('          <note from="Xliff Generator" annotates="general" priority="3">Table Test - Property Caption</note>')
    $sbTransunit.AppendLine('        </trans-unit>')
    $sbBase.Append($sbTransunit)
        
    if ($i -ge 30000 -and $i -lt 30999){ # Modify 1000         
        $sbTransunit = [System.Text.StringBuilder]::new()
        $sbTransunit.AppendLine('        <trans-unit id="ID-AAAAAAAAAAAAA' + $i + '" size-unit="char" translate="yes" xml:space="preserve">')
        $sbTransunit.AppendLine("          <source>Original$i</source>")
        $sbTransunit.AppendLine('          <target state="translated">TranslationLocal' + $i + '</target>')
        $sbTransunit.AppendLine('          <note from="Xliff Generator" annotates="general" priority="3">Table Test - Property Caption</note>')
        $sbTransunit.AppendLine('        </trans-unit>')        
        $sbLocal.Append($sbTransunit)  
    }elseif ($i -lt 10000 -or $i -gt 10999){ # Remove 1000
        $sbLocal.Append($sbTransunit)  
    }
    
    if ($i -ge 40000 -and $i -lt 40999){ # Modify 1000
        $sbTransunit = [System.Text.StringBuilder]::new()
        $sbTransunit.AppendLine('        <trans-unit id="ID-AAAAAAAAAAAAA' + $i + '" size-unit="char" translate="yes" xml:space="preserve">')
        $sbTransunit.AppendLine("          <source>Original$i</source>")
        $sbTransunit.AppendLine('          <target state="translated">TranslationRemote' + $i + '</target>')
        $sbTransunit.AppendLine('          <note from="Xliff Generator" annotates="general" priority="3">Table Test - Property Caption</note>')
        $sbTransunit.AppendLine('        </trans-unit>')        
        $sbRemote.Append($sbTransunit)  
    }elseif ($i -lt 20000 -or $i -gt 20999){ # Remove 1000
        $sbRemote.Append($sbTransunit)
    }
}

for($i=0; $i -lt 500; $i++){
    $sbTransunit = [System.Text.StringBuilder]::new()
    $sbTransunit.AppendLine('        <trans-unit id="ID-AAAAAAAAAAAAALocal' + $i + '" size-unit="char" translate="yes" xml:space="preserve">')
    $sbTransunit.AppendLine("          <source>OriginalLocal$i</source>")
    $sbTransunit.AppendLine('          <target state="translated">TranslationLocal' + $i + '</target>')
    $sbTransunit.AppendLine('          <note from="Xliff Generator" annotates="general" priority="3">Table Test - Property Caption</note>')
    $sbTransunit.AppendLine('        </trans-unit>')
    $sbLocal.Append($sbTransunit)
}


$sbEnd = [System.Text.StringBuilder]::new()
$sbEnd.AppendLine('      </group>')
$sbEnd.AppendLine('    </body>')
$sbEnd.AppendLine('  </file>')
$sbEnd.AppendLine('</xliff>')

$sbOut = [System.Text.StringBuilder]::new()
$sbOut.Append($sbBegin)
$sbOut.Append($sbBase)
$sbOut.AppendLine($sbEnd)

Set-Content -Path ".\test\Resources\Complex-Big\Test.de-DE.xlf.BASE.test" -Value $sbOut.ToString()

$sbOut = [System.Text.StringBuilder]::new()
$sbOut.Append($sbBegin)
$sbOut.Append($sbRemote)
$sbOut.AppendLine($sbEnd)
Set-Content -Path ".\test\Resources\Complex-Big\Test.de-DE.xlf.REMOTE.test" -Value $sbOut.ToString()

$sbOut = [System.Text.StringBuilder]::new()
$sbOut.Append($sbBegin)
$sbOut.Append($sbLocal)
$sbOut.AppendLine($sbEnd)
Set-Content -Path ".\test\Resources\Complex-Big\Test.de-DE.xlf.LOCAL.test" -Value $sbOut.ToString()

