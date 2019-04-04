# Update SharePoint Managed Account Password on: IIS, Windows Services and SharePoint Services
This is a Emergency Powershell Script that change any SharePoint Managed Account User Password if this Managed Account used on SharePoint Services and SharePoint Application Pools and (for some reason) it was not possible to synchronize user changes from Active Directory, like a password expiration and cannot be able to troubleshooting with another layers like Active Directory or Network Infrastructure.
Bellow follow the needed sequence to be sucessful with this scripts; this scripts sequence was tested on several large and/or complex Sharepoint OnPremises Farms at 2010, 2013, 2016 versions, without any impact and with 100% of success in all cases.

### Comments:

i) This scripts execution effect is only on the local machine execution, this not propagate to all Farm Servers;

### Premises:

i) To execute all of these scripts, the current user needs this privilegies bellow:

	i.a)Belongs to Farm Administrator Group;
	
	i.b)local machine Administrator (on any SharePoint Farm server);
	
	i.c)SQL Server SecurityAdmin profile (on SharePoint database instance);
	
	i.d)db_owner on databases "SharePoint_Config" and "SharePoint_Admin_<any guid>";

ii) Before start script sequence, delegate bypassing using this PowerShell instruction:
```powershell
Set-Executionpolicy -Scope CurrentUser -ExecutionPolicy UnRestricted
```
---------------
#### 1) Gets the library for administration of Web Services / Servers:
```powershell
Import-Module WebAdministration
```

#### 2) Gets the user account in the format 'DOMAIN\user':
```powershell
$serviceAccount = Read-Host -Prompt "Please enter the user (in DOMAIN\username format)."
```

#### 3) Gets the user password in Secure String:
```powershell
$servicePasswordSecure = Read-Host "Now, what is this user's password? Please enter (this field will be encrypted)." -AsSecureString
```

#### 4) Transforms the password into clean text:
```powershell
$servicePassPlainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($servicePasswordSecure))
```

#### 5) Gets all Application Pools associated with the user:
```powershell
$applicationPools = Get-ChildItem IIS:\AppPools | where { $_.processModel.userName -eq $serviceAccount }
```

#### 6) Iterates on all Application Pools that the service user has with the new password:
```powershell
foreach($pool in $applicationPools)
{
    $pool.processModel.userName = $serviceAccount
    $pool.processModel.password = $servicePassPlainText
    $pool.processModel.identityType = 3
    $pool | Set-Item
}
```

#### 7) Gets Hostname 'in loco':
```powershell
$serverName = $env:computername
```

#### 8) Gets all services associated with the identified service user:
```powershell
$shpServices = gwmi win32_service -computer $serverName | where {$_.StartName -eq $serviceAccount}
```

#### 9) Runs the change of all Services that the service user has with the new password
```powershell
foreach($service in $shpServices)
{
	$service.change($null,$null,$null,$null,$null,$null,$null,$servicePassPlainText)
}
```

#### 10) Includes in the scope of the program the library responsible for adding SharePoint objects:
```powershell
Add-PSSnapin Microsoft.SharePoint.PowerShell
```

#### 11) Gets the managed service user account in SharePoint:
```powershell
$managedAccount = Get-SPManagedAccount | where {$_.UserName -eq $serviceAccount}
```

#### 12) Change user password in SharePoint:
```powershell
Set-SPManagedAccount -Identity $managedAccount -ExistingPassword $servicePasswordSecure –UseExistingPassword $true

if((Get-SPFarm).DefaultServiceAccount.Name -eq $serviceAccount)
{
	stsadm.exe –o updatefarmcredentials –userlogin $serviceAccount –password $servicePassPlainText
}
```

#### 12) Restart IIS with no forcible:
```powershell
iisreset /noforce
```

That's all folks
