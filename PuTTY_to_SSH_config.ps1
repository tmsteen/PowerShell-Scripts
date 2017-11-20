# PuTTY to SSH Config -- BASH For Windows
# Author: Trevor Steen

# TODO
# Commanline option to write to file

Param(
   [switch]$ForwardAgent
)

# Registry path to PuTTY configured profiles
$regPath = 'HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions'

# Iterate over each PuTTY profile
Get-ChildItem $regPath -Name | ForEach-Object {
    
    # Write the Host for easy SSH use
    Write-Host "Host $_"

    # Parse Hostname for special use cases (Bastion) to create SSH hostname
    $puttyHostname = (Get-ItemProperty -Path "$regPath\$_").HostName
    if ($puttyHostname -like '*@*') {
        $sshHostname = $puttyHostname.split("@")[-1]
        }
    else { $sshHostname = $puttyHostname }
    Write-Host "`tHostName $sshHostname"   
    
    # Parse Hostname for special cases (Bastion) to create User
    if ($puttyHostname -like '*@*') {
        $sshUser = $puttyHostname.split("@")[0..($puttyHostname.split('@').length - 2)] -join '@'
        }
    else { $sshHostname = $puttyHostname }
    Write-Host "`tUser $sshUser"   

    # Parse for Identity File
    $puttyKeyfile = (Get-ItemProperty -Path "$regPath\$_").PublicKeyFile
    if ($puttyKeyfile) { Write-Host "`tIdentityFile $puttyKeyfile" }

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
                Write-Host "`tDynamicForward $tunnelPort $tunnelDest"
            }

            ElseIf ($tunnelType -eq 'R') {

            }

            ElseIf ($tunnelType -eq 'L') {
                Write-Host "`tLocalForward $tunnelPort $tunnelDest"
            }

        }

    }

    #Add Forward Agent if selected
    if ($ForwardAgent) { Write-Host "`tForwardAgent yes" }

    Write-Host "`n"
}
    
