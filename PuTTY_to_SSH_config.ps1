# PuTTY to SSH Config -- BASH For Windows
# Author: Trevor Steen

# Reference:
# Yes/No Menu: https://technet.microsoft.com/en-us/library/ff730939.aspx
# Help Menu: http://kevinpelgrims.com/blog/2010/05/10/add-help-to-your-own-powershell-scripts/

# TO DO
# Commandline option to write directly to local config

<#
.SYNOPSIS
Parse PuTTY profiles into an SSH Config compatible format

.DESCRIPTION
This script parses the registry keys set by PuTTY to save profile configurations.  The applicable parameters are output to either STDOUT or a file that can be copied
into an SSH config.  

-SpaceChar -- Replace spaces in config names with this character (Default: -_
-Append -- Set to append to "OutFile", if not set OutFile is overwritten if it exists
-Prefix -- For keyfile locations; Replace C: with this string (Default: /mnt/c for use with Bash For Windows)

.EXAMPLE
.\PuTTY_to_SSH_config.ps1 -outfile test-in-console.txt -prefix /mnt/c/keyfiles

.NOTES

.LINK
https://ratil.life/powershell-putty-to-ssh
https://github.com/tmsteen/PowerShell-Scripts/blob/master/PuTTY_to_SSH_config.ps1

#>

Param(
    # Specify output file, otherwise STDOUT
    [Parameter(Mandatory=$False)]
        [string]$OutFile,

    # Specify character to replace spaces with, otherwise '-'
    [Parameter(Mandatory=$False)]
        [string]$SpaceChar = '-',

    # Specify if existing file should be overwritten or appended
    [Parameter(Mandatory=$False)]
       [switch]$append = $False,

    # Specify a key prefix
    [Parameter(Mandatory=$False)]
       [string]$prefix = "/mnt/c"
    )

# Menu to prompt user when existing file will be deleted. 
if ($OutFile -And -Not $append -And (Test-Path $OutFile) ) { 
    $title = "Delete File"
    $message = "Use -Append if you want to maintain your existing config. This will delete $OutFile and create a new file.  Is this OK?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Delete file."

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Append file"

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

    switch ($result)
        {
            0 {"You selected Yes."}
            1 {"You selected No."}
        }
    }

if ($result -eq 0) { Remove-Item $OutFile }

# Registry path to PuTTY configured profiles
$regPath = 'HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions'

# Iterate over each PuTTY profile
Get-ChildItem $regPath -Name | ForEach-Object {
    
    # Check if SSH config
    if (((Get-ItemProperty -Path "$regPath\$_").Protocol) -eq 'ssh') {
        # Write the Host for easy SSH use
        $host_nospace = $_.replace('%20', $SpaceChar)
        $hostLine =  "Host $host_nospace"

        # Parse Hostname for special use cases (Bastion) to create SSH hostname
        $puttyHostname = (Get-ItemProperty -Path "$regPath\$_").HostName
        if ($puttyHostname -like '*@*') {
            $sshHostname = $puttyHostname.split("@")[-1]
            }
        else { $sshHostname = $puttyHostname }
        $hostnameLine = "`tHostName $sshHostname"   
    
        # Parse Hostname for special cases (Bastion) to create User
        if ($puttyHostname -like '*@*') {
            $sshUser = $puttyHostname.split("@")[0..($puttyHostname.split('@').length - 2)] -join '@'
            }
        else { $sshHostname = $puttyHostname }
        $userLine = "`tUser $sshUser"   

        # Parse for Identity File
        $puttyKeyfile = (Get-ItemProperty -Path "$regPath\$_").PublicKeyFile
        if ($puttyKeyfile) { 
            $sshKeyfile = $puttyKeyfile.replace('\', '/')
            if ($prefix) { $sshKeyfile = $sshKeyfile.replace('C:', $prefix) }
            $identityLine = "`tIdentityFile $sshKeyfile"
            }

        # Parse Configured Tunnels
        $puttyTunnels = (Get-ItemProperty -Path "$regPath\$_").PortForwardings
        if ($puttyTunnels) {
            $puttyTunnels.split() | ForEach-Object {

                # First character denotes tunnel type
                $tunnelType = $_.Substring(0,1)
                # Digits follow tunnel type is local port
                $tunnelPort = $_ -match '\d*\d(?==)' | Foreach {$Matches[0]}
                # Text after '=' is the tunnel destination
                $tunnelDest = $_.split('=')[1]

                if ($tunnelType -eq 'D') {
                    $tunnelLine = "`tDynamicForward $tunnelPort $tunnelDest"
                }

                ElseIf ($tunnelType -eq 'R') {
                    $tunnelLine = "`tRemoteForward $tunnelPort $tunnelDest"
                }

                ElseIf ($tunnelType -eq 'L') {
                    $tunnelLine = "`tLocalForward $tunnelPort $tunnelDest"
                }

            }

        # Parse if Forward Agent is required
        $puttyAgent = (Get-ItemProperty -Path "$regPath\$_").AgentFwd
        if ($puttyAgent -eq 1) { $agentLine = "`tForwardAgent yes" }

        # Parse if non-default port
        $puttyPort = (Get-ItemProperty -Path "$regPath\$_").PortNumber
        if (-Not $puttyPort -eq 22) { $PortLine = "`tPort $puttyPort" }

        }

        # Build output string
        $output = "$hostLine`n$hostnameLine`n$userLine`n$identityLine`n$tunnelLine`n$agentLine`n"

        # Output to file if set, otherwise STDOUT
        if ($outfile) { $output | Out-File $outfile -Append}
        else { Write-Host $output }
    }
   
}
    
