# Update SharePoint Managed Account Password on all Farm Layers: IIS, Windows Services and SharePoint Services
This is a Emergency Powershell Script that change any SharePoint Managed Account User Password if this Managed Account used on SharePoint Services and SharePoint Application Pools and (for some reason) it was not possible to synchronize user changes from Active Directory, like a password expiration and cannot be able to troubleshooting with another layers like Active Directory or Network Infrastructure.
Bellow follow the needed sequence to be sucessful with this scripts; this scripts sequence was tested on several large and/or complex Sharepoint OnPremises Farms at 2010, 2013, 2016 versions, without any impact and with 100% of success in all cases.

### Comments:

i) This scripts execution effect is only on the local machine execution, this not propagate to all Farm Servers;

### Premises:

ii) To execute all of these scripts, the current user needs this privilegies bellow:

	ii.a)Belongs to Farm Administrator Group;
	
	ii.b)local machine Administrator (on any SharePoint Farm server);
	
	ii.c)SQL Server SecurityAdmin profile (on SharePoint database instance);
	
	ii.d)db_owner on databases "SharePoint_Config" and "SharePoint_Admin_<any guid>";

iii) Before start script sequence, delegate bypassing using this PowerShell instruction [(Set-ExecutionPolicy at Microsoft Docs)](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy):
```powershell
Set-Executionpolicy -Scope CurrentUser -ExecutionPolicy UnRestricted
```
---------------
#### 1) Gets the library for administration of Web Services / Servers [(WebAdministration at Microsoft Docs)](https://docs.microsoft.com/en-us/powershell/module/webadministration):
```powershell
Import-Module WebAdministration
```

#### 2) Gets the user account in the format 'DOMAIN\user' [(Read-Host, Example 1)](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host):
```powershell
$serviceAccount = Read-Host -Prompt "Please enter the user (in DOMAIN\username format)."
```

#### 3) Gets the user password in Secure String [(Read-Host, Example 2)](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host):
```powershell
$servicePasswordSecure = Read-Host "Now, what is this user's password? Please enter (this field will be encrypted)." -AsSecureString
```

#### 4) Transforms the password into clean text [(System.Runtime.InteropServices.marshal, by Andrew Watt)](https://books.google.com.br/books?id=lAvsnA5Ua68C&pg=PA214&lpg=PA214&dq=powershell+runtime.interopservices.marshal&source=bl&ots=XXJ_kHBLb5&sig=ACfU3U1-O-dyDEaq6N2EM0NmTzsmN20caA&hl=pt-BR&sa=X&ved=2ahUKEwjPor7ngbbjAhUBH7kGHWwGDSQ4ChDoATAJegQIAxAB#v=onepage&q=powershell%20runtime.interopservices.marshal&f=false):
```powershell
$servicePassPlainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($servicePasswordSecure))
```

#### 5) Gets all Application Pools associated with the user [(Start-WebAppPool at Microsoft Docs)](https://docs.microsoft.com/en-us/powershell/module/webadminstration/start-webapppool):
```powershell
$applicationPools = Get-ChildItem IIS:\AppPools | where { $_.processModel.userName -eq $serviceAccount }
```

#### 6) Iterates on all Application Pools that the service user has with the new password [(PowerShell Snap-in: Making Configuration Changes to Websites and App Pools at Microsoft Docs)](https://docs.microsoft.com/en-us/iis/manage/powershell/powershell-snap-in-making-simple-configuration-changes-to-web-sites-and-application-pools):
```powershell
foreach($pool in $applicationPools)
{
    $pool.processModel.userName = $serviceAccount
    $pool.processModel.password = $servicePassPlainText
    $pool.processModel.identityType = 3
    $pool | Set-Item
}
```

#### 7) Gets Hostname 'in loco' [(Get computer name at Microsoft DevBlogs)](https://devblogs.microsoft.com/scripting/powertip-use-powershell-to-get-computer-name/):
```powershell
$serverName = $env:computername
```

#### 8) Gets all services associated with the identified service user [(Get-WmiObject at Microsoft Docs)](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-wmiobject):
```powershell
$shpServices = gwmi win32_service -computer $serverName | where {$_.StartName -eq $serviceAccount}
```

#### 9) Runs the change of all Services that the service user has with the new password [(Change method of the Win21_service class at Microsoft Docs)](https://docs.microsoft.com/pt-br/windows/win32/cimwin32prov/change-method-in-class-win32-service)
```powershell
foreach($service in $shpServices)
{
	$service.change($null,$null,$null,$null,$null,$null,$null,$servicePassPlainText)
}
```

#### 10) Includes in the scope of the program the library responsible for adding SharePoint objects [(Add Microsoft.SharePoint.PowerShell Snap-In to All PowerShell Windows at Microsoft Blog)](https://blogs.msdn.microsoft.com/kaevans/2011/11/14/add-microsoft-sharepoint-powershell-snap-in-to-all-powershell-windows/):
```powershell
Add-PSSnapin Microsoft.SharePoint.PowerShell
```

#### 11) Gets the managed service user account in SharePoint [(Get-SPManagedAccount at Microsoft Docs)](https://docs.microsoft.com/en-us/powershell/module/sharepoint-server/get-spmanagedaccount):
```powershell
$managedAccount = Get-SPManagedAccount | where {$_.UserName -eq $serviceAccount}
```

#### 12) Change user password in SharePoint [(Set-SPManagedAccount)](https://docs.microsoft.com/en-us/powershell/module/sharepoint-server/set-spmanagedaccount):
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
----------------------
## License

[View MIT license](https://github.com/antonio-leonardo/UpdateSharePointManagedAccountPassword/blob/master/LICENSE)
