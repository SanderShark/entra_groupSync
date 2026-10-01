<#
.SYNOPSIS
    Syncs members from a Source Entra ID Group to a Destination Entra ID Group using Managed Identity.
.DESCRIPTION
    1. Connects using Azure Automation Managed Identity.
    2. Fetches members from Source and Destination groups.
    3. Adds missing source members to the destination group.
    4. Removes destination members that are no longer in the source group.
#>


# for local execution, commend out if using in automation account
# param(
#    [Parameter(Mandatory = $true)]
#    [string]$SourceGroupId,
#
#    [Parameter(Mandatory = $true)]
#    [string]$DestinationGroupId
#)

Connect-MgGraph -Scopes Groups.ReadWrite.All

$SourceGroupId = "334c896f-ef5c-46bd-887c-ee8103c95032"
$DestinationGroupId = "3897ac3c-dc62-499f-952e-e0958f0482ae"

# Stop execution on fatal errors
$ErrorActionPreference = "Stop"

try {
    Write-Output "Connecting to Microsoft Graph using Managed Identity..."
    # Connect using System-Assigned Managed Identity. 

    # If using User-Assigned, add: -ClientId "<User-Assigned-Managed-Identity-ClientID>"
    # Connect-MgGraph -Identity

    # for connectin with interactive login 
    # connect-mggraph -Scopes Group.readwrite.all
    

    # 1. Get Source Group Members
    Write-Output "Retrieving members from Source Group ($SourceGroupId)..."
    $sourceMembers = Get-MgGroupMember -GroupId $SourceGroupId -All
    $sourceUserIds = $sourceMembers.Id

    # 2. Get Destination Group Members
    Write-Output "Retrieving members from Destination Group ($DestinationGroupId)..."
    $destMembers = Get-MgGroupMember -GroupId $DestinationGroupId -All
    $destUserIds = $destMembers.Id

    # 3. Determine Members to Add and Remove
    $membersToAdd = $sourceUserIds | Where-Object { $_ -notin $destUserIds }
    $membersToRemove = $destUserIds | Where-Object { $_ -notin $sourceUserIds }

    # 4. Add missing members to Destination Group
    if ($membersToAdd) {
        Write-Output "Adding $($membersToAdd.Count) member(s) to destination group..."
        foreach ($userId in $membersToAdd) {
            try {
                # Graph API expects the directory object URL for adding members
                $directoryObjectUrl = "https://graph.microsoft.com/v1.0/directoryObjects/$userId"
                New-MgGroupMemberByRef -GroupId $DestinationGroupId -OdataId $directoryObjectUrl
                Write-Output "  + Added User/Object ID: $userId"
            }
            catch {
                Write-Error "  ! Failed to add User ID ${userId}: ${_}"
            }
        }
    } else {
        Write-Output "No new members to add."
    }

    # 5. Remove extra members from Destination Group
    if ($membersToRemove) {
        Write-Output "Removing $($membersToRemove.Count) member(s) from destination group..."
        foreach ($userId in $membersToRemove) {
            try {
                Remove-MgGroupMemberByRef -GroupId $DestinationGroupId -DirectoryObjectId $userId
                Write-Output "  - Removed User/Object ID: $userId"
            }
            catch {
                Write-Error "  ! Failed to remove User ID ${userId}: ${_}"
            }
        }
    } else {
        Write-Output "No extra members to remove."
    }

    Write-Output "Group synchronization completed successfully."

}
catch {
    Write-Error "An error occurred during synchronization: ${_}"
    throw $_
}
finally {
    # Disconnect Graph Session
    Disconnect-MgGraph
}
