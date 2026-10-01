# Entra ID Group-to-Group Sync Runbook

An automated Azure Automation PowerShell runbook designed to synchronize members from a Source Entra ID group to a Destination Entra ID group using a Managed Identity and Microsoft Graph.

---

## 📌 Background & Why This Is Needed

### 1. The Retirement of the `memberOf` Dynamic Rule Operator
Microsoft has officially announced the retirement of the `memberOf` rule operator in Microsoft Entra ID (Azure AD) dynamic groups. 

Historically, admins used `memberOf` rules to build dynamic membership based on membership in other groups. Because this feature remained in preview and introduced performance and scale bottlenecks, Microsoft is deprecating `memberOf`. Organizations relying on dynamic group rules with `memberOf` must migrate away to avoid stale memberships and access control gaps.

### 2. Device Group Limitations
Even while `memberOf` was available, **it never worked for devices**. The `user.memberof` syntax was only applicable to User objects, meaning administrators had no native way to create dynamic device groups based on existing device group memberships.

### 3. Features That Prohibit Nested Groups
Certain key Entra ID capabilities do **not** support nested group memberships (where Group B is placed inside Group A). In these scenarios, only direct members of the target group are processed:

* **Authentication Staged Rollout Groups**: Features such as Staged Rollout for Password Hash Sync (PHS), Pass-through Authentication (PTA), or Seamless SSO require direct assigned group members.
* **Conditional Access Policies**: While Conditional Access resolves nested user groups, nesting can cause latency or unexpected token evaluation issues.
* **Group-based Licensing**: Assigning licenses to nested groups does not flow down to nested members reliably.
* **Intune Policy & App Assignments**: Device configurations and app assignments often require direct flat group assignments for predictable delivery.

---

## 💡 Solution Overview

This PowerShell script provides a lightweight, automated mechanism to **flatten and synchronize group memberships** without relying on deprecated `memberOf` rules or unsupported group nesting.

### How it Works
1. Connects to Microsoft Graph using an Azure Automation **Managed Identity** (Passwordless / Keyless authentication).
2. Reads the membership of both the **Source Group** and **Destination Group**.
3. **Adds** missing source members to the destination group.
4. **Removes** members from the destination group who are no longer present in the source group.

---

## 🚀 Azure Setup & Prerequisites

### 1. Azure Automation Account Modules
Ensure the following Microsoft Graph modules are installed in your Azure Automation Account:
* `Microsoft.Graph.Authentication`
* `Microsoft.Graph.Groups`

### 2. Managed Identity Permissions
The Automation Account's System-Assigned (or User-Assigned) Managed Identity requires Microsoft Graph permissions to read and update group memberships.

Run the following PowerShell script as a Global Administrator or Privileged Role Administrator to grant `GroupMember.ReadWrite.All` permission to your Managed Identity:

```powershell
# Connect to Microsoft Graph with Directory/App permissions
Connect-MgGraph -Scopes "AppRoleAssignment.ReadWrite.All", "Application.ReadWrite.All"

# Specify your Azure Automation Account Name
$automationAccountName = "YOUR-AUTOMATION-ACCOUNT-NAME"

# Get the Service Principal for the Managed Identity
$msi = Get-MgServicePrincipal -Filter "displayName eq '$automationAccountName'"

# Get the Microsoft Graph Service Principal
$graphApp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

# Find the GroupMember.ReadWrite.All Role
$role = $graphApp.AppRoles | Where-Object { $_.Value -eq "GroupMember.ReadWrite.All" }

# Assign the App Role to the Managed Identity
New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $msi.Id `
    -PrincipalId $msi.Id `
    -ResourceId $graphApp.Id `
    -RoleId $role.Id
```

---

## 🛠️ Usage

### Azure Automation Runbook Parameters

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `SourceGroupId` | `String` | **Yes** | The Object ID of the source Entra ID group. |
| `DestinationGroupId` | `String` | **Yes** | The Object ID of the destination group to be synced. |

### Running the Script

1. Create a new PowerShell Runbook in your Azure Automation Account (PowerShell version 7.x recommended).
2. Paste the contents of `group2group.ps1`.
3. Save and Publish the Runbook.
4. Create a **Schedule** (e.g., hourly or daily) and link it to the runbook, passing the `SourceGroupId` and `DestinationGroupId` as parameters.

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
