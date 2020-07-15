#########################################################################################################
#########################################################################################################
############################### Author: Antonio Leonardo de Abreu Freire ################################
#### Microsoft Certified ID: 13271836, vide https://www.youracclaim.com/users/antonioleonardo/badges ####
#########################################################################################################
## Update SharePoint Account Password on all Farm Layers: IIS, Windows Services and SharePoint Services #
#########################################################################################################
#########################################################################################################
########### Don't Forget this Script Premisses! The current user to execute this script needs: ##########
########### a)Belongs to Farm Administrator Group; ######################################################
########### b)local machine Administrator (on any SharePoint Farm server); ##############################
########### c)SQL Server SecurityAdmin profile (on SharePoint database instance); #######################
########### d)db_owner on databases "SharePoint_Config" and "SharePoint_Admin_<any guid>"; ##############
#########################################################################################################
#########################################################################################################
#########################################################################################################

#Setting execution policy for current user is unrestricted, forcing to disable confirm dialog
Write-Host "Setting execution policy for current user is unrestricted, forcing to disable confirm dialog."
Set-Executionpolicy -Scope CurrentUser -ExecutionPolicy UnRestricted -Force 

#Gets the library for administration of Web Services / Servers:
Write-Host "Start routine for alterações de Senha do IIS, para o usuário de Serviços." -ForegroundColor Yellow
Import-Module WebAdministration
Write-Host "01-Gets the library for administration of Web Services / Servers." -ForegroundColor Green

#Gets the user account in the format 'DOMAIN\user':'
$serviceAccount = Read-Host -Prompt "Please enter the user (in DOMAIN\username format)."
Write-Host "02-User login loaded." -ForegroundColor Green

#Gets the user password in Secure String:
$servicePasswordSecure = Read-Host "Now, what is this user's password? Please enter (this field will be encrypted)." -AsSecureString
Write-Host "03-User password loaded." -ForegroundColor Green

#Transforms the password into clean text:
$servicePassPlainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($servicePasswordSecure))
Write-Host "04-Transformed the password into clean text:" -ForegroundColor Green

Write-Host "05-Gets all Application Pools associated with the user $($serviceAccount)." -ForegroundColor Green
#Gets all Application Pools associated with the user:
$applicationPools = Get-ChildItem IIS:\AppPools | where { $_.processModel.userName -eq $serviceAccount }

#Iterates on all Application Pools that the service user has with the new password:
Write-Host "06-Alter passwords on IIS Application Pool running... Please, wait." -ForegroundColor Green
foreach($pool in $applicationPools)
{
    $pool.processModel.userName = $serviceAccount
    $pool.processModel.password = $servicePassPlainText
    $pool.processModel.identityType = 3
    $pool | Set-Item
}
Write-Host "07-Ok, thanks. Application Pools updated with success." -ForegroundColor Green
Write-Host "End routine to alter passwords on IIS layer." -ForegroundColor Yellow

Write-Host "Starts another routine, to alter passwords on Windows Service accounts, if current user is associated with any service account." -ForegroundColor Yellow

#Gets Hostname 'in loco':
$serverName = $env:computername
Write-Host "08-Gets Hostname 'in loco'." -ForegroundColor Green

#Gets all services associated with the identified service user:
$shpServices = gwmi win32_service -computer $serverName | where {$_.StartName -eq $serviceAccount}
Write-Host "09-Gets all services associated with the identified service user $($serviceAccount)." -ForegroundColor Green

#Runs the change of all Services that the service user has with the new password
Write-Host "10-Alter passwords on Windows Services running... Please, wait." -ForegroundColor Green
foreach($service in $shpServices)
{
	$service.change($null,$null,$null,$null,$null,$null,$null,$servicePassPlainText)
}
Write-Host "11-Ok, thanks. Services account updated with success.." -ForegroundColor Green

#Includes in the scope of the program the library responsible for adding SharePoint objects:
Add-PSSnapin Microsoft.SharePoint.PowerShell
Write-Host "12-Includes in the scope of the program the library responsible for adding SharePoint objects." -ForegroundColor Green

#Gets the managed service user account in SharePoint:
$managedAccount = Get-SPManagedAccount | where {$_.UserName -eq $serviceAccount}
Write-Host "13-Gets the managed service user account in SharePoint." -ForegroundColor Green

#Change user password in SharePoint:
Set-SPManagedAccount -Identity $managedAccount -ExistingPassword $servicePasswordSecure  –UseExistingPassword:$true -Confirm:$False
if((Get-SPFarm).DefaultServiceAccount.Name -eq $serviceAccount)
{
	stsadm.exe –o updatefarmcredentials –userlogin $serviceAccount –password $servicePassPlainText
}
Write-Host "14-Change user password in SharePoint with success." -ForegroundColor Green

#Restart IIS:
Write-Host "15-Restart IIS with no force." -ForegroundColor Green
iisreset /noforce
