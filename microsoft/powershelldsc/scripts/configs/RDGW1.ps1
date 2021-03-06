﻿param(
    [string]$DomainDNSName,
    [string]$DomainNetBiosName,
    [string]$AdminPassword,
    [string]$ADServer1PrivateIp,
    [string]$ADServer2PrivateIp
    )

Configuration LCMConfig {
    LocalConfigurationManager {
        RebootNodeIfNeeded = $true
        CertificateID = (Get-ChildItem Cert:\LocalMachine\My)[0].Thumbprint
    }
}

LCMConfig
Set-DscLocalConfigurationManager -Path .\LCMConfig

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'RDGW1'
            CertificateFile = 'C:\dsc.cer'
        }
    )
}

$Pass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBiosName\administrator", $Pass

Configuration RDGW1Config {
    Import-DscResource -ModuleName xNetworking, xComputerManagement

    Node RDGW1 {
        xDnsServerAddress DnsServerAddress { 
            Address        = $ADServer1PrivateIp, $ADServer2PrivateIp
            InterfaceAlias = 'Ethernet' 
            AddressFamily  = 'IPv4' 
        }

        WindowsFeature RDGateway {
            Name = 'RDS-Gateway'
            Ensure = 'Present'
        }

        WindowsFeature RDGatewayTools {
            Name = 'RSAT-RDS-Gateway'
            Ensure = 'Present'
        }

        xComputer JoinDomain {
            Name = 'RDGW1'
            DomainName = $DomainDNSName
            Credential = $Credential
            DependsOn = "[xDnsServerAddress]DnsServerAddress"
        }
    }
}

RDGW1Config -ConfigurationData $ConfigurationData
Start-DscConfiguration -Path .\RDGW1Config -Wait -Verbose