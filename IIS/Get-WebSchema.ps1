####  Copy and paste from here!!!
#
#     -------------------------- EXAMPLE 1 --------------------------
#     C:\> Get-WebSchema -list
#     This command retrieves the list of schema files that are available.
#
#     -------------------------- EXAMPLE 2 --------------------------
#     C:\> Get-WebSchema -list -fileName "$env:windir\system32\inetsrv\config\schema\IIS_schema.xml"
#     This command retrieves the list of sections that are available for IIS_Schema.xml file.
#
#     -------------------------- EXAMPLE 3 --------------------------
#     C:\> Get-WebSchema -list -fileName "$env:windir\system32\inetsrv\config\schema\IIS_schema.xml" -sectionName system.webServer/asp
#     This command retrieves an xml node object for the asp section in Iis_Schema.xml file.
#
#     -------------------------- EXAMPLE 4 --------------------------
#     C:\> Get-WebSchema -fileName "$env:windir\system32\inetsrv\config\schema\IIS_schema.xml" -sectionName system.webServer/asp
#     This command list all config information (Ie. attribute/method/element/collection) of the asp section
#
#     -------------------------- EXAMPLE 5 --------------------------
#     C:\> Get-WebSchema -fileName "$env:windir\system32\inetsrv\config\schema\IIS_schema.xml"
#     This command list all config information (Ie. attribute/method/element/collection) of the IIS_Schema file
#
#     -------------------------- EXAMPLE 6 --------------------------
#     C:\> $iis
#     This command will dump all available config sections
#
#     -------------------------- EXAMPLE 7 --------------------------
#     C:\> $iis.site
#     This command will return string value of the full config path such as system.applicationHost/sites/site
#
#     -------------------------- EXAMPLE 8 --------------------------
#     C:\> $iis.appSettings._file
#     This command will return string value of the attribute name, such as "file", of the appSettings config section. 
#     (NOTE: for quick find attribute name, I put "_" string at the beginning of attribute name. 
#     For the example, $iis.appSettings._<TAB> will show $iis.appSettings._file.

function global:Get-WebSchema()
{
    param(
        [string]$fileName=$null,
        [string]$sectionName=$null,
        [object]$nodeObject=$null,
        [switch]$list,
        [switch]$verbose
    )

    if ($list -and $sectionName -and -not $fileName)
    {
        throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
    }

    if ($list -and $recurse)
    {
        throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
    }

    if ($sectionName -and -not $fileName)
    {
        throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
    }

    if ($list)
    {
        if ($sectionName)
        {
            [xml]$xml = Get-Content $filename
            $rootNode = $xml.get_documentElement()
            $rootNode.sectionSchema | ForEach-Object {
                $nodeObject = $_                
                if ($nodeObject.name.tolower() -eq $sectionName.tolower())
                {                  
                    $nodeObject
                }
            }             
        }
        else
        {
            if ($fileName)
            {
                [xml]$xml = Get-Content $filename
                $rootNode = $xml.get_documentElement()
                $rootNode.sectionSchema | ForEach-Object {
                    $sectionName = $_.name
                    $sectionName
                }           
            }
            else
            {
                Get-ChildItem "$env:windir\system32\inetsrv\config\schema" -filter *.xml | ForEach-Object {
                    $filePath = $_.fullname
                    $filePath
                }
            }
        }    
    }
    else
    {
        if (-not $fileName -and -not $nodeObject) {
            throw $($(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'fileName')
        }

        if (-not $nodeObject)
        {
            [xml]$xml = Get-Content $filename
            $rootNode = $xml.get_documentElement()
            $rootNode.sectionSchema | ForEach-Object {
                $nodeObject = $_
                if ((-not $sectionName) -or ($nodeObject.name.tolower() -eq $sectionName.tolower()))
                {
                    Get-WebSchema -nodeObject $_ -filename $fileName -sectionName $nodeObject.name -verbose:$verbose
                }
            }            
        }       
        else
        {
            ("element", "collection", "attribute", "method") | ForEach-Object {
                $type = $_.tostring()
                if ($nodeObject.$type -ne $null) 
                {   
                    $nodeObject.$type | ForEach-Object {
                         $leafObject = $_
                         $output = new-object psobject
                         if ($type -eq "collection") 
                         {
                             $name = $leafObject.addElement
                             if ($verbose)
                             {
                                 $name = "[name]"
                             }
                         }
                         else
                         {
                             $name = $leafObject.name
                         }                       

                         $ItemXPath = $null
                         if ($verbose)
                         {
                             $ItemXPath = ($sectionName+"//"+$name)
                         }
                         else
                         {
                             $ItemXPath = ($sectionName+"/"+$name)
                         }
                         add-member -in $output noteproperty ItemXPath $ItemXPath
                         add-member -in $output noteproperty Name $name
                         add-member -in $output noteproperty XmlObject $leafObject
                         add-member -in $output noteproperty Type $leafObject.toString()
                         add-member -in $output noteproperty ParentXPath $sectionName
                         $output

                         if ($type -eq "element" -or $type -eq "collection") 
                         {
                             Get-WebSchema -nodeObject $_ -filename $fileName -sectionName $ItemXPath -verbose:$verbose
                         }
                    }
                }
            }
        }
    }
}

$global:iis = new-object psobject
(dir "$env:windir\system32\inetsrv\config\schema\*.xml") | sort -Descending | select FullName,Name | foreach {
  $file = $_.Name
  $filepath = $_.FullName
  
  $saved_section = $null
  $sectionName = $null   
  $sectionValue = $null   

  Get-WebSchema -fileName $filePath | where {$_.Type -eq "attribute"} | foreach {
    $sectionPath = $_.ParentXPath
    $attribute = $_.Name

    ##
    ## when a new section is found
    ##
    if ($saved_section -ne $sectionPath) { 
 
      if ($sectionName -ne $null)  
      {
        ##
        ## Now that the $sectionvalue is made for a specific config section, 
        ## let's add the unique $sectionName noteproperty with $sectionName value onto $iis object
        ##
        add-member -in $iis noteproperty $sectionName $sectionValue 
      }

      ##
      ## Let's create a new $sectionValue with assigning a new sectionPath value
      ##
      $sectionValue = $sectionPath

      ##
      ## Let's get an unique $sectionName which was not used before
      ##
      $tokens = $sectionPath.split("/")
      $sectionName = $tokens[$tokens.length-1]

      if ($tokens.length -gt 1 -and $tokens[$tokens.length-1] -eq "add") 
      {
        $sectionName = $tokens[$tokens.length-2] + "_" + $tokens[$tokens.length-1]
      }
      
      ##
      ## if existing one has the same section configPath, copy it to the $sectionValue and then remove existing one in order to append
      ##
      if ($iis.$sectionName -ne $null -and $iis.$sectionName -eq $sectionPath) 
      {
        $sectionValue = $iis.$sectionName
        $iis = $iis | select * -exclude $sectionName
      }
      
      if ($iis.$sectionName -ne $null) 
      {
        $i = 2;
        do 
        {
          $temp = $sectionName + $i
          $i = $i + 1
        } 
        while ($iis.$temp -ne $null)            
        $sectionName = $temp
      }

      # reset $saved_section variable with the new section path
      $saved_section = $sectionPath
    }

    ##
    ## Let's add all of the attributes as a child noteproperty onto the $sectionValue string object
    ##
    $sectionValue = $sectionValue | add-member -membertype noteproperty -name ("_"+$attribute) -value $attribute -passthru 
  }

  if ($sectionName -ne $null)
  {
    ##
    ## Let's process the last $sectionValue after loop statement 
    ##
    add-member -in $iis noteproperty $sectionName $sectionValue 
  }
}