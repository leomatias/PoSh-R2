﻿<#
.SYNOPSIS
    PoSH-R2 is a set of Windows Management Instrumentation interface (WMI) scripts that investigators and forensic analysts can use to retrieve information from a
    compromised (or potentially compromised) Windows system. The scripts use WMI to pull this information from the operating system. Therefore, this script
    will need to be executed with a user that has the necessary privileges.

    PoSH-R2 will retrieve the following data from an individual machine or a group of systems:
            - Autorun entries
            - Disk info
            - Environment variables
            - Event logs (50 latest)
            - Installed Software (Warning: https://gregramsey.net/2012/02/20/win32_product-is-evil/)
            - Logon sessions
            - List of drivers
            - List of mapped network drives
            - List of running processes
            - Logged in user
            - Local groups
            - Local user accounts
            - Network configuration
            - Network connections
            - Patches
            - Scheduled tasks with AT command
            - Shares
            - Services
            - System Information

.EXAMPLE
    .\posh_r2.ps1

.NOTES  
    File Name      : PoSH-R2.ps1
    Version        : v.0.2
    Author         : @WiredPulse
    Prerequisite   : PowerShell
    Created        : 10 Oct 16
#>

Import-Module "$PSScriptRoot\PSSQLite\PSSQLite.psd1"

# ==============================================================================
# Function Name 'ListComputers' - Takes entered domain and lists all computers
# ==============================================================================
Function ListComputers
{
    $DN = ""
    $Response = ""
    $DNSName = ""
    $DNSArray = ""
    $objSearcher = ""
    $colProplist = ""
    $objComputer = ""
    $colResults = ""
    $comp = ""
    New-Item -type file -force "$Script:Folder_Path\Computer_List_$Script:curDate.txt" | Out-Null
    $Script:Compute = "$Script:Folder_Path\Computer_List_$Script:curDate.txt"
    $strCategory = "(ObjectCategory=Computer)"
    
    Write-Host "Would you like to automatically pull from your domain or provide your own domain?"
    Write-Host "Auto pull uses the current domain you are on, if you need to select a different domain use manual."
    $response = Read-Host = "[1] Auto Pull, [2] Manual Selection"
    
    If($Response -eq "1") {
        $DNSName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
        If($DNSName -ne $Null) {
            $DNSArray = $DNSName.Split(".") 
            for ($x = 0; $x -lt $DNSArray.Length ; $x++) {  
                if ($x -eq ($DNSArray.Length - 1)){$Separator = ""}else{$Separator =","} 
                [string]$DN += "DC=" + $DNSArray[$x] + $Separator  } }
        $Script:Domain = $DN
        Write-Output "Pulled computers from: "$Script:Domain 
        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher("LDAP://$Script:Domain")
        $objSearcher.Filter = $strCategory
        $objSearcher.PageSize = 100000
        $objSearcher.SearchScope = "SubTree"
        $colProplist = "name"
        foreach ($i in $colPropList) {
            $objSearcher.propertiesToLoad.Add($i) }
        $colResults = $objSearcher.FindAll()
        foreach ($objResult in $colResults) {
            $objComputer = $objResult.Properties
            $comp = $objComputer.name
            Write-Output $comp | Out-File $Script:Compute -Append }
        $Script:Computers = (Get-Content $Script:Compute) | Sort-Object
    }
	elseif($Response -eq "2")
    {
        Write-Host "Would you like to automatically pull from your domain or provide your own domain?"
        Write-Host "Auto pull uses the current domain you are on, if you need to select a different domain use manual."
        $Script:Domain = Read-Host "Enter your Domain here: OU=West,DC=Company,DC=com"
        If ($Script:Domain -eq $Null) {Write-Host "You did not provide a valid response."; . ListComputers}
        Write-Output "Pulled computers from: "$Script:Domain 
        $objOU = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Script:Domain")
        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
        $objSearcher.SearchRoot = $objOU
        $objSearcher.Filter = $strCategory
        $objSearcher.PageSize = 100000
        $objSearcher.SearchScope = "SubTree"
        $colProplist = "name"
        foreach ($i in $colPropList) { $objSearcher.propertiesToLoad.Add($i) }
        $colResults = $objSearcher.FindAll()
        foreach ($objResult in $colResults) {
            $objComputer = $objResult.Properties
            $comp = $objComputer.name
            Write-Output $comp | Out-File $Script:Compute -Append }
        $Script:Computers = (Get-Content $Script:Compute) | Sort-Object
    }
    else {
        Write-Host "You did not supply a correct response, Please select a response." -foregroundColor Red
        . ListComputers }
}

# ==============================================================================
# Function Name 'ListTextFile' - Enumerates Computer Names in a text file
# Create a text file and enter the names of each computer. One computer
# name per line. Supply the path to the text file when prompted.
# ==============================================================================
Function ListTextFile 
{
	$file_Dialog = ""
    $file_Name = ""
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $file_Dialog = New-Object system.windows.forms.openfiledialog
    $file_Dialog.InitialDirectory = "$env:USERPROFILE\Desktop"
    $file_Dialog.MultiSelect = $false
    $file_Dialog.showdialog()
    $file_Name = $file_Dialog.filename
    $Comps = Get-Content $file_Name
    If ($Comps -eq $Null) {
        Write-Host "Your file was empty. You must select a file with at least one computer in it." -Fore Red
        . ListTextFile }
    Else
    {
        $Script:Computers = @()
        ForEach ($Comp in $Comps)
        {
            If ($Comp -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}")
            {
                $Temp = $Comp.Split("/")
                $IP = $Temp[0]
                $Mask = $Temp[1]
                . Get-Subnet-Range $IP $Mask
                $Script:Computers += $Script:IPList
            }
            Else
            {
                $Script:Computers += $Comp
            }
        }

        
    }
}

Function Get-Subnet-Range {
    #.Synopsis
    # Lists all IPs in a subnet.
    #.Example
    # Get-Subnet-Range -IP 192.168.1.0 -Netmask /24
    #.Example
    # Get-Subnet-Range -IP 192.168.1.128 -Netmask 255.255.255.128        
    Param(
        [string]
        $IP,
        [string]
        $netmask
    )  
    Begin {
        $IPs = New-Object System.Collections.ArrayList

        Function Get-NetworkAddress {
            #.Synopsis
            # Get the network address of a given lan segment
            #.Example
            # Get-NetworkAddress -IP 192.168.1.36 -mask 255.255.255.0
            Param (
                [string]
                $IP,
               
                [string]
                $Mask,
               
                [switch]
                $Binary
            )
            Begin {
                $NetAdd = $null
            }
            Process {
                $BinaryIP = ConvertTo-BinaryIP $IP
                $BinaryMask = ConvertTo-BinaryIP $Mask
                0..34 | ForEach-Object{
                    $IPBit = $BinaryIP.Substring($_,1)
                    $MaskBit = $BinaryMask.Substring($_,1)
                    IF ($IPBit -eq '1' -and $MaskBit -eq '1') {
                        $NetAdd = $NetAdd + "1"
                    } elseif ($IPBit -eq ".") {
                        $NetAdd = $NetAdd +'.'
                    } else {
                        $NetAdd = $NetAdd + "0"
                    }
                }
                if ($Binary) {
                    return $NetAdd
                } else {
                    return ConvertFrom-BinaryIP $NetAdd
                }
            }
        }
       
        Function ConvertTo-BinaryIP {
            #.Synopsis
            # Convert an IP address to binary
            #.Example
            # ConvertTo-BinaryIP -IP 192.168.1.1
            Param (
                [string]
                $IP
            )
            Process {
                $out = @()
                Foreach ($octet in $IP.split('.')) {
                    $strout = $null
                    0..7|ForEach-Object {
                        IF (($octet - [math]::pow(2,(7-$_)))-ge 0) {
                            $octet = $octet - [math]::pow(2,(7-$_))
                            [string]$strout = $strout + "1"
                        } else {
                            [string]$strout = $strout + "0"
                        }  
                    }
                    $out += $strout
                }
                return [string]::join('.',$out)
            }
        }
 
 
        Function ConvertFrom-BinaryIP {
            #.Synopsis
            # Convert from Binary to an IP address
            #.Example
            # Convertfrom-BinaryIP -IP 11000000.10101000.00000001.00000001
            Param (
                [string]
                $IP
            )
            Process {
                $out = @()
                Foreach ($octet in $IP.split('.')) {
                    $strout = 0
                    0..7|ForEach-Object {
                        $bit = $octet.Substring(($_),1)
                        IF ($bit -eq 1) {
                            $strout = $strout + [math]::pow(2,(7-$_))
                        }
                    }
                    $out += $strout
                }
                return [string]::join('.',$out)
            }
        }

        Function ConvertTo-MaskLength {
            #.Synopsis
            # Convert from a netmask to the masklength
            #.Example
            # ConvertTo-MaskLength -Mask 255.255.255.0
            Param (
                [string]
                $mask
            )
            Process {
                $out = 0
                Foreach ($octet in $Mask.split('.')) {
                    $strout = 0
                    0..7|ForEach-Object {
                        IF (($octet - [math]::pow(2,(7-$_)))-ge 0) {
                            $octet = $octet - [math]::pow(2,(7-$_))
                            $out++
                        }
                    }
                }
                return $out
            }
        }
 
        Function ConvertFrom-MaskLength {
            #.Synopsis
            # Convert from masklength to a netmask
            #.Example
            # ConvertFrom-MaskLength -Mask /24
            #.Example
            # ConvertFrom-MaskLength -Mask 24
            Param (
                [int]
                $mask
            )
            Process {
                $out = @()
                [int]$wholeOctet = ($mask - ($mask % 8))/8
                if ($wholeOctet -gt 0) {
                    1..$($wholeOctet) |ForEach-Object{
                        $out += "255"
                    }
                }
                $subnet = ($mask - ($wholeOctet * 8))
                if ($subnet -gt 0) {
                    $octet = 0
                    0..($subnet - 1) | ForEach-Object{
                         $octet = $octet + [math]::pow(2,(7-$_))
                    }
                    $out += $octet
                }
                for ($i=$out.count;$i -lt 4; $I++) {
                    $out += 0
                }
                return [string]::join('.',$out)
            }
        }

        Function Get-IPRange {
            #.Synopsis
            # Given an Ip and subnet, return every IP in that lan segment
            #.Example
            # Get-IPRange -IP 192.168.1.36 -Mask 255.255.255.0
            #.Example
            # Get-IPRange -IP 192.168.5.55 -Mask /23
            Param (
                [string]
                $IP,
               
                [string]
                $netmask
            )
            Process {
                iF ($netMask.length -le 3) {
                    $masklength = $netmask.replace('/','')
                    $Subnet = ConvertFrom-MaskLength $masklength
                } else {
                    $Subnet = $netmask
                    $masklength = ConvertTo-MaskLength -Mask $netmask
                }
                $network = Get-NetworkAddress -IP $IP -Mask $Subnet
               
                [int]$FirstOctet,[int]$SecondOctet,[int]$ThirdOctet,[int]$FourthOctet = $network.split('.')
                $TotalIPs = ([math]::pow(2,(32-$masklength)) -2)
                $blocks = ($TotalIPs - ($TotalIPs % 256))/256
                if ($Blocks -gt 0) {
                    1..$blocks | ForEach-Object{
                        0..255 |ForEach-Object{
                            if ($FourthOctet -eq 255) {
                                If ($ThirdOctet -eq 255) {
                                    If ($SecondOctet -eq 255) {
                                        $FirstOctet++
                                        $secondOctet = 0
                                    } else {
                                        $SecondOctet++
                                        $ThirdOctet = 0
                                    }
                                } else {
                                    $FourthOctet = 0
                                    $ThirdOctet++
                                }  
                            } else {
                                $FourthOctet++
                            }
                            Write-Output ("{0}.{1}.{2}.{3}" -f `
                            $FirstOctet,$SecondOctet,$ThirdOctet,$FourthOctet)
                        }
                    }
                }
                $sBlock = $TotalIPs - ($blocks * 256)
                if ($sBlock -gt 0) {
                    1..$SBlock | ForEach-Object{
                        if ($FourthOctet -eq 255) {
                            If ($ThirdOctet -eq 255) {
                                If ($SecondOctet -eq 255) {
                                    $FirstOctet++
                                    $secondOctet = 0
                                } else {
                                    $SecondOctet++
                                    $ThirdOctet = 0
                                }
                            } else {
                                $FourthOctet = 0
                                $ThirdOctet++
                            }  
                        } else {
                            $FourthOctet++
                        }
                        Write-Output ("{0}.{1}.{2}.{3}" -f `
                        $FirstOctet,$SecondOctet,$ThirdOctet,$FourthOctet)
                    }
                }
            }
        }
    }
    Process {
        #get every ip in scope
        Get-IPRange $IP $netmask | foreach-object{
        [void]$IPs.Add($_)
        }
        $Script:IPList = $IPs
    }
}

# ==============================================================================
# Function Name 'SingleEntry' - Enumerates Computer from user input
# ==============================================================================
Function SingleEntry 
{
    $Comp = Read-Host "Enter Computer Name or IP (1.1.1.1) or IP Subnet (1.1.1.1/24)"
    If ($Comp -eq $Null) { . SingleEntry } 
    ElseIf ($Comp -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}")
    {
        $Temp = $Comp.Split("/")
        $IP = $Temp[0]
        $Mask = $Temp[1]
        . Get-Subnet-Range $IP $Mask
        $Script:Computers = $Script:IPList
    }
    Else
    { $Script:Computers = $Comp}
}

$script:autorunDB = "$PSScriptRoot" + "\PoSh-R2_data\db\autorun.SQLite"
$script:logonDB = "$PSScriptRoot" + "\PoSh-R2_data\db\logon.SQLite"
$script:secEvtDB = "$PSScriptRoot" + "\PoSh-R2_data\db\secevt.SQLite"
$script:sysEvtDB = "$PSScriptRoot" + "\PoSh-R2_data\db\sysevt.SQLite"
$script:appEvtDB = "$PSScriptRoot" + "\PoSh-R2_data\db\appevt.SQLite"
$script:driverDB = "$PSScriptRoot" + "\PoSh-R2_data\db\driver.SQLite"
$script:mappedDB = "$PSScriptRoot" + "\PoSh-R2_data\db\mappeddrive.SQLite"
$script:processDB = "$PSScriptRoot" + "\PoSh-R2_data\db\process.SQLite"
$script:schedtasksDB = "$PSScriptRoot" + "\PoSh-R2_data\db\schedtasks.SQLite"
$script:servicesDB = "$PSScriptRoot" + "\PoSh-R2_data\db\services.SQLite"
$script:envDB = "$PSScriptRoot" + "\PoSh-R2_data\db\env.SQLite"
$script:userInfoDB = "$PSScriptRoot" + "\PoSh-R2_data\db\userinfo.SQLite"
$script:groupDB = "$PSScriptRoot" + "\PoSh-R2_data\db\groups.SQLite"
$script:loggedinDB = "$PSScriptRoot" + "\PoSh-R2_data\db\loggedin.SQLite"
$script:networkDB = "$PSScriptRoot" + "\PoSh-R2_data\db\network.SQLite"
$script:sharesDB = "$PSScriptRoot" + "\PoSh-R2_data\db\shares.SQLite"
$script:diskDB = "$PSScriptRoot" + "\PoSh-R2_data\db\disk.SQLite"
$script:sysinfoDB = "$PSScriptRoot" + "\PoSh-R2_data\db\sysinfo.SQLite"
$script:patchDB = "$PSScriptRoot" + "\PoSh-R2_data\db\patch.SQLite"
$script:softwareDB = "$PSScriptRoot" + "\PoSh-R2_data\db\software.SQLite"
$script:netstatDB = "$PSScriptRoot" + "\PoSh-R2_data\db\netstat.SQLite"


Write-Host "  ______                   _______  __    __          ______      ___    " -ForegroundColor Green
Write-Host " |   _  \                 /      | |  |  |  |        |   _  \    |__ \   " -ForegroundColor Green
Write-Host " |  |_)  |   ______      |   (---- |  |__|  |  ______|  |_)  |      ) |  " -ForegroundColor Green
Write-Host " |   ___/   /  __  \      \   \    |   __   | |______|      /      / /   " -ForegroundColor Green
Write-Host " |  |      |  |__|  | |----)   |   |  |  |  |        |  |\  \-----/ /_   " -ForegroundColor Green
Write-Host " | _|       \______/  |_______/    |__|  |__|        | _| \_____|_____|  " -ForegroundColor Green
Write-Host ""

Write-Host "What systems do you get to interrogate?"	-ForegroundColor yellow
$strResponse = Read-Host "`n[1] All Domain Computers (Must provide Domain) `n[2] Import Computer Names/ IPs from a File `n[3] Input Computer Names/ IPs Manually `n[4] Local System `n"
If($strResponse -eq "1"){. ListComputers | Sort-Object}
	elseif($strResponse -eq "2"){. ListTextFile}
	elseif($strResponse -eq "3"){. SingleEntry}
	elseif($strResponse -eq "4"){$localhost = $computers = "localhost"}
	else{Write-Host "You did not supply a correct response, `
	Please run script again."; pause -foregroundColor Red}				

Write-Host "Got computer list... Next task..." -ForegroundColor yellow
write-output " "

if (-not(test-path "$PSScriptRoot\PoSh-R2_Data")){
    new-item  -ItemType Directory -path "$PSScriptRoot" -name "PoSh-R2_Data" | out-null
}
if(-not(test-path "$PSScriptRoot\PoSh-R2_Data\db")){
    new-item -ItemType directory -path "$PSScriptRoot\PoSh-R2_Data" -Name "db" | out-null
}

$dirDate = get-date -Format yyyy-MM-dd-HHmm
new-item -ItemType Directory -path "$PSScriptRoot\PoSh-R2_Data" -Name "$dirDate" | out-null

if(-not(test-path "$autorunDB")){
$Query = 'CREATE TABLE autorun (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    name TEXT,
    location TEXT,
    command TEXT,
    user TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $autorunDB | Out-Null
}

if(-not(test-path "$diskDB")){
$Query = 'CREATE TABLE disk (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    deviceid TEXT,
    description TEXT,
    providername TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $diskDB | Out-Null
}

if(-not(test-path "$driverDB")){
$Query = 'CREATE TABLE drivers (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    name TEXT,
    installdate TEXT,
    displayname TEXT,
    pathname TEXT,
    state TEXT,
    startmode TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $driverDB | Out-Null
}

if(-not(test-path "$envDB")){
$Query = 'CREATE TABLE env (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    username TEXT,
    name TEXT,
    variablevalue TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $envDB | Out-Null
}

if(-not(test-path "$appEvtDB")){
$Query = 'CREATE TABLE appevt (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    logfile TEXT,
    eventcode TEXT,
    timegenerated TEXT,
    message TEXT,
    type TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $appEvtDB | Out-Null
}
if(-not(test-path "$secEvtDB")){
$Query = 'CREATE TABLE secevt (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    logfile TEXT,
    eventcode TEXT,
    timegenerated TEXT,
    message TEXT,
    type TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $secEvtDB | Out-Null
}

if(-not(test-path "$sysEvtDB")){
$Query = 'CREATE TABLE sysevt (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    logfile TEXT,
    eventcode TEXT,
    timegenerated TEXT,
    message TEXT,
    type TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $sysEvtDB | Out-Null
}

if(-not(test-path "$groupDB")){
$Query = 'CREATE TABLE groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    caption TEXT,
    domain TEXT,
    name TEXT,
    sid TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $groupDB | Out-Null
}

if(-not(test-path "$logonDB")){
$Query = 'CREATE TABLE netlogon (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    name TEXT,
    lastlogon TEXT,
    lastlogoff TEXT,
    numberoflogons TEXT,
    passwordage TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $logonDB | Out-Null
}

if(-not(test-path "$loggedinDB")){
$Query = 'CREATE TABLE loggedinuser (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    username TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $loggedinDB | Out-Null
}

if(-not(test-path "$mappedDB")){
$Query = 'CREATE TABLE mappeddrives (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    providername TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $mappedDB | Out-Null
}

if(-not(test-path "$processDB")){
$Query = 'CREATE TABLE process (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    name TEXT,
    path TEXT,
    commandline TEXT,
    description TEXT,
    processid TEXT,
    parentprocessid TEXT,
    handle TEXT,
    handlecount TEXT,
    threadcount TEXT,
    creationdate TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $processDB | Out-Null
}

if(-not(test-path "$schedtasksDB")){
    $Query = 'CREATE TABLE schedtask (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    name TEXT,
    owner TEXT,
    jobid TEXT,
    command TEXT,
    runrepeatedly TEXT,
    interactwithdesktop TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $schedtasksDB | Out-Null
}

if(-not(test-path "$servicesDB")){
    $Query = 'CREATE TABLE services (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    processid TEXT,
    name TEXT,
    description TEXT,
    pathname TEXT,
    started TEXT,
    startmode TEXT,
    startname TEXT,
    state TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $servicesDB | Out-Null
}

if(-not(test-path "$userInfoDB")){
    $Query = 'CREATE TABLE useraccount (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    accounttype TEXT,
    fullname TEXT,
    domain TEXT,
    disabled TEXT,
    localaccount TEXT,
    lockedout TEXT,
    passwordchangeable TEXT,
    passwordexpires TEXT,
    sid TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $userInfoDB | Out-Null
}

if(-not(test-path "$networkDB")){
    $Query = 'CREATE TABLE networks (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    ipaddress TEXT,
    ipsubnet TEXT,
    defaultipgateway TEXT,
    dhcpserver TEXT,
    dnshostname TEXT,
    dnsserversearchorder TEXT,
    macaddress TEXT,
    description TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $networkDB | Out-Null
}

if(-not(test-path "$sharesDB")){
        $Query = 'CREATE TABLE shares (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    name TEXT,
    path TEXT,
    description TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $sharesDB | Out-Null
}

if(-not(test-path "$sysinfoDB")){
        $Query = 'CREATE TABLE computersystem (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    domain TEXT,
    model TEXT,
    manufacturer TEXT,
    enabledaylightsavingstime TEXT,
    partofdomain TEXT,
    roles TEXT,
    systemtype TEXT,
    numberofprocessors TEXT,
    totalphysicalmemory TEXT,
    username TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $sysinfoDB | Out-Null
}

if(-not(test-path "$patchDB")){
        $Query = 'CREATE TABLE patch (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    hotfixid TEXT,
    description TEXT,
    installedby TEXT,
    installedon TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $patchDB | Out-Null
}

if(-not(test-path "$softwareDB")){
        $Query = 'CREATE TABLE software (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    name TEXT,
    packetcache TEXT,
    vendor TEXT,
    version TEXT,
    identifyingnumber TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $softwareDB | Out-Null
}

if(-not(test-path "$netstatDB")){
            $Query = 'CREATE TABLE connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
    date DATETIME,
    computername TEXT,
    protocol TEXT,
    version TEXT,
    localaddress TEXT,
    localport TEXT,
    remoteaddress TEXT,
    remoteport TEXT,
    state TEXT,
    processid TEXT,
    processname TEXT,
    processpath TEXT)'

Invoke-SqliteQuery -Query $Query -DataSource $netstatDB | Out-Null
}

# ==============================================================================
# Autorun information
# ==============================================================================
Write-Host "Retrieving Autoruns information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_startupcommand -ComputerName $computers | Select-Object PSComputername, Name, Location, Command, User | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Autoruns.csv -NoTypeInformation

# ==============================================================================
# Logon information
# ==============================================================================
Write-Host "Retrieving logon information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_networkloginprofile -ComputerName $computers | Select-Object PSComputername,Name, LastLogon,LastLogoff,NumberOfLogons,PasswordAge | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\NetLogon.csv -NoTypeInformation

# ==============================================================================
# Event log information (Note: If logs are not returning data, ensure the script 
# is not ran from the ISE console)
# ==============================================================================
Write-Host "Retrieving event log information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_ntlogevent -ComputerName $computers -filter "logfile='security'" | Select-Object PSComputername, LogFile, EventCode, TimeGenerated, Message, Type | Select-Object -first 50 | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-Security.csv -NoTypeInformation
Get-WMIObject -Namespace root\cimv2 -Class win32_ntlogevent -ComputerName $computers -filter "logfile='system'" | Select-Object PSComputername, LogFile, EventCode, TimeGenerated, Message, Type | Select-Object -first 50 | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-System.csv -NoTypeInformation
Get-WMIObject -Namespace root\cimv2 -Class win32_ntlogevent -ComputerName $computers -filter "logfile='application'" | Select-Object PSComputername, LogFile, EventCode, TimeGenerated, Message, Type | Select-Object -first 50 | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-Application.csv -NoTypeInformation

# ==============================================================================
# Driver information
# ==============================================================================
Write-Host "Retrieving driver information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_systemdriver -ComputerName $computers | Select-Object PSComputername, Name, InstallDate, DisplayName, PathName, State, StartMode | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Drivers.csv -NoTypeInformation

# ==============================================================================
# Mapped drives information
# ==============================================================================
Write-Host "Retrieving mapped drives information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_mappedlogicaldisk -ComputerName $computers | Select-Object PSComputername, Name, ProviderName | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Mapped_Drives.csv -NoTypeInformation

# ==============================================================================
# Process information
# ==============================================================================
Write-Host "Retrieving running processes information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_process -ComputerName $computers | Select-Object PSComputername, Name, path, Commandline, Description, ProcessID, ParentProcessID, Handle, HandleCount, ThreadCount, CreationDate | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Processes.csv -NoTypeInformation

# ==============================================================================
# Scheduled tasks
# ==============================================================================
Write-Host "Retrieving scheduled tasks created by at.exe or Win32_ScheduledJob..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_scheduledjob -ComputerName $computers | Select-Object PSComputername, Name, Owner, JodID, Command, RunRepeatedly, InteractWithDesktop | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Scheduled_Tasks.csv -NoTypeInformation

# ==============================================================================
# Services
# ==============================================================================
Write-Host "Retrieving service information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_service -ComputerName $computers | Select-Object PSComputername, ProcessID, Name, Description, PathName, Started, StartMode, StartName, State | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Services.csv -NoTypeInformation

# ==============================================================================
# Environment variables
# ==============================================================================
Write-Host "Retrieving environment variables information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_environment -ComputerName $computers | Select-Object PSComputername, UserName, Name, VariableValue | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Environment_Variables.csv -NoTypeInformation

# ==============================================================================
# User information
# ==============================================================================
Write-Host "Retrieving user information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_useraccount -ComputerName $computers | Select-Object PSComputername, accounttype, name, fullname, domain, disabled, localaccount, lockout, passwordchangeable, passwordexpires, sid | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Users.csv -NoTypeInformation

# ==============================================================================
# Group information
# ==============================================================================
Write-Host "Retrieving group information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_group -ComputerName $computers |Select-Object PSComputername, Caption, Domain, Name, Sid | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Groups.csv -NoTypeInformation

# ==============================================================================
# Logged in user
# ==============================================================================
Write-Host "Retrieving loggedon user information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_computersystem -ComputerName $computers | Select-Object PSComputername, Username | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Logged_on_User.csv -NoTypeInformation

# ==============================================================================
# Network settings
# ==============================================================================
Write-Host "Retrieving network configurations..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_networkadapterconfiguration -ComputerName $computers | Select-Object PSComputername, IPAddress, IPSubnet, DefaultIPGateway, DHCPServer, DNSHostname, DNSserversearchorder, MACAddress, description| Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Network_Configs.csv -NoTypeInformation

# ==============================================================================
# Shares
# ==============================================================================
Write-Host "Retrieving shares information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_share -ComputerName $computers |Select-Object PSComputername, Name, Path, Description | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Shares.csv -NoTypeInformation

# ==============================================================================
# Disk information
# ==============================================================================
Write-Host "Retrieving disk information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_logicaldisk -ComputerName $computers | Select-Object PSComputername, DeviceID, Description, ProviderName | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Disk.csv -NoTypeInformation

# ==============================================================================
# System information
# ==============================================================================
Write-Host "Retrieving system information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_computersystem -ComputerName $computers | Select-Object PSComputername, Domain, Model, Manufacturer, EnableDaylightSavingsTime, PartOfDomain, Roles, SystemType, NumberOfProcessors, TotalPhysicalMemory, Username | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\System_Info.csv -NoTypeInformation

# ==============================================================================
# Patch information
# ==============================================================================
Write-Host "Retrieving installed patch information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_quickfixengineering -ComputerName $computers | Select-Object PSComputername, HotFixID, Description, InstalledBy, InstalledOn | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Patches.csv -NoTypeInformation

# ==============================================================================
# Installed Software... Warning: https://gregramsey.net/2012/02/20/win32_product-is-evil/
# ==============================================================================
Write-Host "Retrieving installed software information..." -ForegroundColor yellow
Get-WMIObject -Namespace root\cimv2 -Class win32_product -ComputerName $computers | Select-Object PSComputername, Name, PackageCache, Vendor, Version, IdentifyingNumber | Export-CSV $PSScriptRoot\PoSh-R2_data\$dirDate\Software.csv -NoTypeInformation

#set-location .\connects

# ==============================================================================
# Network connections
# ==============================================================================
Write-Host "Retrieving network connections..." -ForegroundColor yellow
if($localhost -eq $null){
foreach($computer in $computers){
Invoke-WmiMethod -Class Win32_Process -Name Create -Computername $computer -ArgumentList "cmd /c netstat -ano > c:\$computer.txt" >$null 2>&1
copy-item \\$computer\c$\$computer.txt $PSScriptRoot\PoSh-R2_data\$dirDate
$connections = get-content $PSScriptRoot\PoSh-R2_data\$dirDate\$computer.txt
    $NetStatRecords = @()
    $Connections[4..$Connections.count] | foreach-object {
        Write-Verbose "Parsing line: $_ "
        $Fragments = ($_ -replace '\s+', ' ').Split(' ')
        if ($Fragments[2].Contains('[')) { 
            $Version       = 'IPv6'
            $LocalAddress  = $Fragments[2].Split(']')[0].Split('[')[1]
            $LocalPort     = $Fragments[2].Split(']')[1].Split(':')[1]            
        } else { 
            $Version       = 'IPv4'
            $LocalAddress  = $Fragments[2].Split(':')[0] 
            $LocalPort     = $Fragments[2].Split(':')[1]
        }
        if ($Fragments[3].Contains('[')) { 
            $RemoteAddress = $Fragments[3].Split(']')[0].Split('[')[1]
            $RemotePort    = $Fragments[3].Split(']')[1].Split(':')[1]
        } else { 
            $RemoteAddress = $Fragments[3].Split(':')[0] 
            $RemotePort    = $Fragments[3].Split(':')[1]
        }
        $ProcessID = $(if ($RemoteAddress -eq '*') {$Fragments[4]} else {$Fragments[5]})
        $Props = [ordered]@{
            ComputerName = $computer
            Protocol      = $Fragments[1]
            Version       = $Version
            LocalAddress  = $LocalAddress
            LocalPort     = $LocalPort
            RemoteAddress = $RemoteAddress
            RemotePort    = $RemotePort
            State         = $(if ($RemoteAddress -eq '*') {''} else {$Fragments[4]}) 
            ProcessID     = $ProcessID
            ProcessName   = $((Get-Process -Id $ProcessID).Name)
            ProcessPath   = $((Get-Process -Id $ProcessID).Path)
        }
        $Record = New-Object -TypeName PSObject -Property $Props
        $NetStatRecords += $Record
    }

$NetStatRecords | export-csv $PSScriptRoot\PoSh-R2_data\$dirDate\connections.csv -NoTypeInformation -Append
Remove-Variable NetStatRecords
remove-item $PSScriptRoot\PoSh-R2_data\$dirDate\$computer.txt
}
remove-item \\$computer\c$\$computer.txt 
Remove-Variable localhost -ErrorAction SilentlyContinue
}

else{
    
    $connections = netstat -ano
    $NetStatRecords = @()
    $Connections[4..$Connections.count] | foreach-object {
        Write-Verbose "Parsing line: $_ "
        $Fragments = ($_ -replace '\s+', ' ').Split(' ')
        if ($Fragments[2].Contains('[')) { 
            $Version       = 'IPv6'
            $LocalAddress  = $Fragments[2].Split(']')[0].Split('[')[1]
            $LocalPort     = $Fragments[2].Split(']')[1].Split(':')[1]            
        } else { 
            $Version       = 'IPv4'
            $LocalAddress  = $Fragments[2].Split(':')[0] 
            $LocalPort     = $Fragments[2].Split(':')[1]
        }
        if ($Fragments[3].Contains('[')) { 
            $RemoteAddress = $Fragments[3].Split(']')[0].Split('[')[1]
            $RemotePort    = $Fragments[3].Split(']')[1].Split(':')[1]
        } else { 
            $RemoteAddress = $Fragments[3].Split(':')[0] 
            $RemotePort    = $Fragments[3].Split(':')[1]
        }
        $ProcessID = $(if ($RemoteAddress -eq '*') {$Fragments[4]} else {$Fragments[5]})
        $Props = [ordered]@{
            ComputerName = $computer
            Protocol      = $Fragments[1]
            Version       = $Version
            LocalAddress  = $LocalAddress
            LocalPort     = $LocalPort
            RemoteAddress = $RemoteAddress
            RemotePort    = $RemotePort
            State         = $(if ($RemoteAddress -eq '*') {''} else {$Fragments[4]}) 
            ProcessID     = $ProcessID
            ProcessName   = $((Get-Process -Id $ProcessID).Name)
            ProcessPath   = $((Get-Process -Id $ProcessID).Path)
        }
        $Record = New-Object -TypeName PSObject -Property $Props
        $NetStatRecords += $Record
    }

$NetStatRecords | export-csv $PSScriptRoot\PoSh-R2_data\$dirDate\connections.csv -NoTypeInformation -Append
Remove-Variable NetStatRecords
}

# ==============================================================================
# Cleaning up
# ==============================================================================
#remove-item $PSScriptRoot\PoSh-R2_data\connects -recurse -force
#remove-item \\$computer\c$\$computer.txt 
Write-host "Done!"-ForegroundColor Cyan
Write-output "..."
Write-Host "Importing data to databases..." -ForegroundColor yello
Write-Output " "

$autorun = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Autoruns.csv
$disk = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Disk.csv
$drivers = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Drivers.csv
$envVar = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Environment_Variables.csv
$evtApp = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-Application.csv
$evtSec = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-Security.csv
$evtSys = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-System.csv
$groups = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Groups.csv
$loggedon = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Logged_on_User.csv
$mapped = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Mapped_Drives.csv
$netlogon = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\NetLogon.csv
$net = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Network_Configs.csv
$patch = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Patches.csv
$process = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Processes.csv
$sched = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Scheduled_Tasks.csv
$serv = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Services.csv
$shares = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Shares.csv
$software = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Software.csv
$sysInfo = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\System_Info.csv
$users = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\Users.csv
$connects = import-csv $PSScriptRoot\PoSh-R2_data\$dirDate\connections.csv

$autorunQuery = 'INSERT INTO autorun (date, computername, name, location, command, user)
            VALUES (@date, @computername, @name, @location, @command, @user)'

$diskQuery = 'INSERT INTO disk (date, computername, deviceid, description, providername)
            VALUES (@date, @computername, @deviceid, @description, @providername)'

$driversQuery = 'INSERT INTO drivers (date, computername, name, installdate, displayname, pathname, state, startmode)
            VALUES (@date, @computername, @name, @installdate, @displayname, @pathname, @state, @startmode)'

$envQuery = 'INSERT INTO env (date, computername, username, name, variablevalue)
            VALUES (@date, @computername, @username, @name, @variablevalue)'

$appevtQuery = 'INSERT INTO appevt (date, computername, logfile, eventcode, timegenerated, message, type)
            VALUES (@date, @computername, @logfile, @eventcode, @timegenerated, @message, @type)'

$secevtQuery = 'INSERT INTO secevt (date, computername, logfile, eventcode, timegenerated, message, type)
            VALUES (@date, @computername, @logfile, @eventcode, @timegenerated, @message, @type)'

$sysevtQuery = 'INSERT INTO sysevt (date, computername, logfile, eventcode, timegenerated, message, type)
            VALUES (@date, @computername, @logfile, @eventcode, @timegenerated, @message, @type)'

$groupsQuery = 'INSERT INTO groups (date, computername, caption, domain, name, sid)
            VALUES (@date, @computername, @caption, @domain, @name, @sid)'

$loggedinuserQuery = 'INSERT INTO loggedinuser (date, computername, username)
            VALUES (@date, @computername, @username)'

$netlogonQuery = 'INSERT INTO netlogon (date, computername, name, lastlogon, lastlogoff, numberoflogons, passwordage)
            VALUES (@date, @computername, @name, @lastlogon, @lastlogoff, @numberoflogons, @passwordage)'

$mappeddrivesQuery = 'INSERT INTO mappeddrives (date, computername, providername)
            VALUES (@date, @computername, @providername)'

$processQuery = 'INSERT INTO process (date, computername, name, path, commandline, description, processid, parentprocessid, handle, handlecount, threadcount, creationdate)
            VALUES (@date, @computername, @name, @path, @commandline, @description, @processid, @parentprocessid, @handle, @handlecount, @threadcount, @creationdate)'

$schedtaskQuery = 'INSERT INTO schedtask (date, computername, name, owner, jobid, command, runrepeatedly, interactwithdesktop)
            VALUES (@date, @computername, @name, @owner, @jobid, @command, @runrepeatedly, @interactwithdesktop)'

$servicesQuery = 'INSERT INTO services (date, computername, processid, name, description, pathname, started, startmode, startname, state)
            VALUES (@date, @computername, @processid, @name, @description, @pathname, @started, @startmode, @startname, @state)'

$useraccountQuery = 'INSERT INTO useraccount (date, computername, accounttype, fullname, domain, disabled, localaccount, lockedout, passwordchangeable, passwordexpires, sid)
            VALUES (@date, @computername, @accounttype, @fullname, @domain, @disabled, @localaccount, @lockedout, @passwordchangeable, @passwordexpires, @sid)'

$networksQuery = 'INSERT INTO networks (date, computername, ipaddress, ipsubnet, defaultipgateway, dhcpserver, dnshostname, dnsserversearchorder, macaddress, description)
            VALUES (@date, @computername, @ipaddress, @ipsubnet, @defaultipgateway, @dhcpserver, @dnshostname, @dnsserversearchorder, @macaddress, @description)'

$sharesQuery = 'INSERT INTO shares (date, computername, name, path, description)
            VALUES (@date, @computername, @name, @path, @description)'

$computersystemQuery = 'INSERT INTO computersystem (date, computername, domain, model, manufacturer, enabledaylightsavingstime, partofdomain, roles, systemtype, numberofprocessors, totalphysicalmemory, username)
            VALUES (@date, @computername, @domain, @model, @manufacturer, @enabledaylightsavingstime, @partofdomain, @roles, @systemtype, @numberofprocessors, @totalphysicalmemory, @username)'

$patchQuery = 'INSERT INTO patch (date, computername, hotfixid, description, installedby, installedon)
            VALUES (@date, @computername, @hotfixid, @description, @installedby, @installedon)'

$softwareQuery = 'INSERT INTO software (date, computername, name, packetcache, vendor, version, identifyingnumber)
            VALUES (@date, @computername, @name, @packetcache, @vendor, @version, @identifyingnumber)'

$connectionsQuery = 'INSERT INTO connections (date, computername, protocol, version, localaddress, localport, remoteaddress, remoteport, state, processid, processname, processpath)
            VALUES (@date, @computername, @protocol, @version, @localaddress, @localport, @remoteaddress, @remoteport, @state, @processid, @processname, @processpath)'


foreach($item in $autorun){

    Invoke-SqliteQuery -DataSource $autorunDB -Query $autorunQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Autoruns.csv).CreationTimeUtc
        computername  = $item.pscomputername
        name  = $item.name
        location = $item.location
        command = $item.command
        user = $item.user
    } | Out-Null

}

foreach($item in $disk){

    Invoke-SqliteQuery -DataSource $diskDB -Query $diskQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\disk.csv).CreationTimeUtc
        computername = $item.pscomputername
        deviceid = $item.deviceid
        description = $item.description
        providername = $item.providername
    } | Out-Null

}

foreach($item in $drivers){

    Invoke-SqliteQuery -DataSource $driverDB -Query $driversQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\drivers.csv).CreationTimeUtc
        computername = $item.pscomputername
        name = $item.name
        installdate = $item.installdate
        displayname = $item.displayname
        pathname = $item.pathname
        state = $item.state
        startmode = $item.startmode
    } | Out-Null

}

foreach($item in $envVar){

    Invoke-SqliteQuery -DataSource $envDB -Query $envQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Environment_Variables.csv).CreationTimeUtc
        computername  = $item.pscomputername
        username  = $item.username
        name = $item.name
        variablevalue = $item.variablevalue
    } | Out-Null

}

foreach($item in $evtApp){

    Invoke-SqliteQuery -DataSource $appEvtDB -Query $appevtQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-Application.csv).CreationTimeUtc
        computername  = $item.pscomputername
        logfile  = $item.logfile
        eventcode = $item.eventcode
        timegenerated = $item.timegenerated
        message = $item.Message
        type = $item.type
    } | Out-Null

}

foreach($item in $evtSec){

    Invoke-SqliteQuery -DataSource $secEvtDB -Query $secevtQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-Security.csv).CreationTimeUtc
        computername  = $item.pscomputername
        logfile  = $item.logfile
        eventcode = $item.eventcode
        timegenerated = $item.timegenerated
        message = $item.Message
        type = $item.type
    } | Out-Null

}

foreach($item in $evtSys){

    Invoke-SqliteQuery -DataSource $sysEvtDB -Query $sysevtQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Eventlogs-System.csv).CreationTimeUtc
        computername  = $item.pscomputername
        logfile  = $item.logfile
        eventcode = $item.eventcode
        timegenerated = $item.timegenerated
        message = $item.Message
        type = $item.type
    } | Out-Null

}

foreach($item in $groups){

    Invoke-SqliteQuery -DataSource $groupDB -Query $groupsQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Groups.csv).CreationTimeUtc
        computername  = $item.pscomputername
        caption  = $item.caption
        domain = $item.domain
        name = $item.name
        sid = $item.sid
    } | Out-Null

}


foreach($item in $loggedon){

    Invoke-SqliteQuery -DataSource $loggedinDB -Query $loggedinuserQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Logged_on_User.csv).CreationTimeUtc
        computername  = $item.pscomputername
        username = $item.username
    } | Out-Null

}

foreach($item in $mapped){

    Invoke-SqliteQuery -DataSource $mappedDB -Query $mappeddrivesQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Mapped_Drives.csv).CreationTimeUtc
        computername  = $item.pscomputername
        providername = $item.providername
    } | Out-Null

}

foreach($item in $process){

    Invoke-SqliteQuery -DataSource $processDB -Query $processQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Processes.csv).CreationTimeUtc
        computername  = $item.pscomputername
        name = $item.name
        path = $item.path
        commandline = $item.commandline
        description = $item.description
        processid = $item.processid
        parentprocessid = $item.parentprocessid
        handle = $item.handle
        handlecount = $item.handlecount
        threadcount = $item.threadcount
        creationdate = $item.creationdate
    } | Out-Null

}

foreach($item in $sched){

    Invoke-SqliteQuery -DataSource $schedtasksDB -Query $schedtaskQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Scheduled_Tasks.csv).CreationTimeUtc
        computername  = $item.pscomputername
        name = $item.name
        owner = $item.owner
        jobid = $item.jobid
        command = $item.command
        runrepeatedly = $item.runrepeatedly
        interactwithdesktop = $item.interactwithdesktop
    } | Out-Null

}


foreach($item in $serv){

    Invoke-SqliteQuery -DataSource $servicesDB -Query $servicesQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Services.csv).CreationTimeUtc
        computername  = $item.pscomputername
        processid = $item.processid
        name = $item.name
        description = $item.description
        pathname = $item.pathname
        started = $item.started
        startmode = $item.startmode
        startname = $item.startname
        state = $item.state
    } | Out-Null

}

foreach($item in $users){

    Invoke-SqliteQuery -DataSource $userInfoDB -Query $useraccountQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Users.csv).CreationTimeUtc
        computername  = $item.pscomputername
        accounttype = $item.accounttype
        fullname = $item.fullname
        domain = $item.domain
        disabled = $item.disabled
        localaccount = $item.localaccount
        lockedout = $item.lockedout
        passwordchangeable = $item.passwordchangeable
        passwordexpires = $item.passwordexpires
        sid = $item.sid
    } | Out-Null

}


foreach($item in $net){

    Invoke-SqliteQuery -DataSource $networkDB -Query $networksQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Network_Configs.csv).CreationTimeUtc
        computername  = $item.pscomputername
        ipaddress = $item.ipaddress
        ipsubnet = $item.ipsubnet
        defaultipgateway = $item.defaultipgateway
        dhcpserver = $item.dhcpserver
        dnshostname = $item.dnshostname
        dnsserversearchorder = $item.dnsserversearchorder
        macaddress = $item.macaddress
        description = $item.description
    } | Out-Null
}

foreach($item in $netlogon){

    Invoke-SqliteQuery -DataSource $logonDB -Query $netlogonQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\NetLogon.csv).CreationTimeUtc
        computername  = $item.pscomputername
        name = $item.name
        lastlogon = $item.lastlogon
        lastlogoff = $item.lastlogoff
        numberoflogons = $item.numberoflogons
        passwordage = $item.passwordage
    } | Out-Null
}
foreach($item in $shares){

    Invoke-SqliteQuery -DataSource $sharesDB -Query $sharesQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Shares.csv).CreationTimeUtc
        computername  = $item.pscomputername
        name = $item.name
        path = $item.path
        description = $item.description
    } | Out-Null
}


foreach($item in $sysInfo){

    Invoke-SqliteQuery -DataSource $sysinfoDB -Query $computersystemQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\System_Info.csv).CreationTimeUtc
        computername  = $item.pscomputername
        domain = $item.domain
        model = $item.model
        manufacturer = $item.manufacturer
        enabledaylightsavingstime = $item.enabledaylightsavingstime
        partofdomain = $item.partofdomain
        roles =$item.roles
        systemtype = $item.systemtype
        numberofprocessors = $item.numberofprocessors
        totalphysicalmemory = $item.totalphysicalmemory
        username = $item.username
    } | Out-Null
}

foreach($item in $patch){

    Invoke-SqliteQuery -DataSource $patchDB -Query $patchQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Patches.csv).CreationTimeUtc
        computername  = $item.pscomputername
        hotfixid = $item.hotfixid
        description = $item.description
        installedby = $item.installedby
        installedon = $item.installedon
    } | Out-Null
}

foreach($item in $software){

    Invoke-SqliteQuery -DataSource $softwareDB -Query $softwareQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\Software.csv).CreationTimeUtc
        computername  = $item.pscomputername
        name = $item.name
        packetcache = $item.packetcache
        vendor = $item.vendor
        version = $item.version
        identifyingnumber = $item.identifyingnumber
    } | Out-Null
}

foreach($item in $connects){

    Invoke-SqliteQuery -DataSource $netstatDB -Query $connectionsQuery -SqlParameters @{
        date = (get-item $PSScriptRoot\PoSh-R2_data\$dirDate\connections.csv).CreationTimeUtc
        computername  = $item.pscomputername
        protocol = $item.protocol
        version = $item.version
        localaddress = $item.localaddress
        localport = $item.localport
        remoteaddress = $item.remoteaddress
        remoteport = $item.remoteport
        state = $item.state
        processid = $item.processid
        processname = $item.processname
        processpath = $item.processpath

    } | Out-Null
}

Write-host "Done!"-ForegroundColor Cyan