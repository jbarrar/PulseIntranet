Import-Module MSOnline
Import-Module Microsoft.Online.SharePoint.PowerShell

# add SharePoint CSOM libraries
Import-Module 'C:\Program Files\Common Files\microsoft shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll'
Import-Module 'C:\Program Files\Common Files\microsoft shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll'
Import-Module 'C:\Program Files\Common Files\microsoft shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.UserProfiles.dll'

# Defaults
$spoAdminUrl = "https://superserver-admin.sharepoint.com"
$overwriteExistingSPOUPAValue = "False"

# Get credentials of account that is AzureAD Admin and SharePoint Online Admin
$credential = Get-Credential

Try {
    # Connect to AzureAD
    Connect-MsolService -Credential $credential

    # Get credentials for SharePointOnline
    $spoCredentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($credential.GetNetworkCredential().Username, (ConvertTo-SecureString $credential.GetNetworkCredential().Password -AsPlainText -Force))
    $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($spoAdminUrl)
    $ctx.Credentials = $spoCredentials
    $spoPeopleManager = New-Object Microsoft.SharePoint.Client.UserProfiles.PeopleManager($ctx)

    # Get all AzureAD Users
    $AzureADUsers = Get-MSolUser -All

    ForEach ($AzureADUser in $AzureADUsers) {

        $mobilePhone = $AzureADUser.MobilePhone
        $targetUPN = $AzureADUser.UserPrincipalName.ToString()
        $targetSPOUserAccount = ("i:0#.f|membership|" + $targetUPN)

        # Check to see if the AzureAD User has a MobilePhone specified
        if (!([string]::IsNullOrEmpty($mobilePhone))) {
            # Get the existing value of the SPO User Profile Property CellPhone
            $targetUserCellPhone = $spoPeopleManager.GetUserProfilePropertyFor($targetSPOUserAccount, "CellPhone")
            $ctx.ExecuteQuery()

            $userCellPhone = $targetUserCellPhone.Value
            $userMobilePhone = $mobilePhone.ToString()
            Write-Output "$targetUPN mobile number int SharePoint is $userCellPhone"
            Write-Output "$targetUPN mobile number in AzureAD is $userMobilePhone"
            # If target property is empty let's populate it
            if ([string]::IsNullOrEmpty($userCellPhone)) {
                $targetspoUserAccount = ("i:0#.f|membership|" + $AzureADUser.UserPrincipalName.ToString())
                $spoPeopleManager.SetSingleValueProfileProperty($targetspoUserAccount, "CellPhone", $mobilePhone)
                $ctx.ExecuteQuery()
            }
            else {
                # Target property is not empty
                # Check to see if we're to overwrite existing property value
                if ($overwriteExistingSPOUPAValue -eq "True") {
                    $targetspoUserAccount = ("i:0#.f|membership|" + $AzureADUser.UserPrincipalName.ToString())
                    $spoPeopleManager.SetSingleValueProfileProperty($targetspoUserAccount, "CellPhone", $mobilePhone)
                    $ctx.ExecuteQuery()
                }
                else {
                    # Not going to overwrite existing property value
                    Write-Output "Target SPO UPA CellPhone is not empty for $targetUPN and we're to preserve existing properties"
                }
            }
        }
        else {
            # AzureAD User MobilePhone is empty, nothing to do here
            # Write-Output "AzureAD MobilePhone Property is Null or Empty for $targetUPN"
        }
    }
}
Catch {
    [Exception]
}