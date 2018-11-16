<#	
    #TODO: Add managed by for groups


	.NOTES
	===========================================================================
	 Created on:   	11/15/2018 11:56 AM
	 Created by:   	Bradley Wyatt
	 Filename:      Sync-Office365ToADDS.ps1	
	===========================================================================
	.REQUIREMENTS
		MSONLINE Module (Install-Module MSOnline)
	.DESCRIPTION
		The PowerShell function will connect to your Office 365 and can re-create your Users, Groups, and Contacts in Active Directory. 
		This is extremly helpful if you are looking to change your identity source from Office 365 to Active Directory and then have Active Directory sync up to Office 365.

		This will not copy every attribute from your users over. It will copy what is needed for AADConnect to then SMTP match your Office 365 users to your on-premise users. 
		This will also re-create Distribution, Security, and Mail-Enabled Security Groups and also populate the membership. Distribution and Mail-Enabled security groups will SMTP match when you configure AADConnect.

		USER ATTRIBUTES IT WILL COPY OVER
		- First Name
		- Last Name
		- Display Name
		- User Principal Name
		- Email Address
		- Proxy Addresses 
		- Office
		- Title
		- Department
		- City
		- Office Phone (telephone number)

		MAIL CONTACTS ATTRIBUTES IT WILL COPY OVER
		- Display Name
		- External Email 
		- First Name
		- Last Name

		DISTRIBUTION GROUPS ATTRIBUTES IT WILL COPY OVER
		- Name
		- Display Name
		- Primary SmtpAddress 
		- Description
		- Members

		MAIL-ENABLED SECURITY GROUPS ATTRIBUTES IT WILL COPY OVER
		- Name
		- Display Name
		- Primary SmtpAddress 
		- Description
		- Members

		SECURITY GROUPS ATTRIBUTES IT WILL COPY OVER
		- Name
		- Display Name
		- Primary SmtpAddress 
		- Description
		- Members

	.PARAMETER SyncUsers
		[switch] Syncs Office 365 Users to ADDS

	.PARAMETER UsersOU
		[string] Optional. Can specify which OU to create the users in

	.PARAMETER PasswordForAllUsers
		[string] Required if you use the SyncUsers switch. Specifies the password that will be set for all users that are created. Converts the plain text string to secure.string

	.PARAMETER SyncContacts
		[switch] Syncs Office 365 Mail Contacts to ADDS

	.PARAMETER ContactsOU
		[string] Optional. Can specify which OU to create the mail contacts in

	.PARAMETER SyncDistributionGroups
		[switch] Syncs Office 365 Distribution Groups to ADDS

	.PARAMETER DistributionGroupsOU
		[string] Optional. Can specify which OU to create the Distribution Groups in

	.PARAMETER SyncMailEnabledSecurityGroups
		[switch] Syncs Office 365 Mail Enabled Security Groups to ADDS

	.PARAMETER MailEnabledSecurityGroupsOU
		[string] Optional. Can specify which OU to create the Mail-Enabled Security Groups in

	.PARAMETER SyncSecurityGroups
		[switch] Syncs Office 365 Security Groups to ADDS

	.PARAMETER DistributionGroupsOU
		[string] Optional. Can specify which OU to create the Security Groups in

	.EXAMPLE
		Sync-Office365ToADDS -SyncUsers -PaswordForAllUsers "Temp123!"

	.EXAMPLE
		Sync-Office365ToADDS -SyncContacts -SyncDistributionGroups

	.EXAMPLE
		Sync-Office365ToADDS -SyncSecurityGroups -SecurityGroupsOU "OU=Users,OU=bwya77,DC=lazyadmin,DC=com"

	.EXAMPLE
		Sync-Office365ToADDS -SyncUsers -PaswordForAllUsers "Temp123" "OU=Users,OU=Chicago,DC=lazyadmin,DC=com"
		
#>
function Sync-Office365ToADDS
{
	Param (
		[Parameter(ParameterSetName = 'SyncUsers')]
		[switch]$SyncUsers,
		[Parameter(ParameterSetName = 'SyncUsers', Mandatory = $false)]
		[string]$UsersOU,
		[Parameter(ParameterSetName = 'SyncUsers', Mandatory = $true)]
		[string]$PasswordForAllUsers,
		[Parameter(ParameterSetName = 'SyncContacts')]
		[switch]$SyncContacts,
		[Parameter(ParameterSetName = 'SyncContacts', Mandatory = $false)]
		[string]$ContactsOU,
		[Parameter(ParameterSetName = 'SyncDistributionGroups')]
		[switch]$SyncDistributionGroups,
		[Parameter(ParameterSetName = 'SyncDistributionGroups', Mandatory = $false)]
		[string]$DistributionGroupsOU,
		[Parameter(ParameterSetName = 'SyncMailEnabledSecurityGroups')]
		[switch]$SyncMailEnabledSecurityGroups,
		[Parameter(ParameterSetName = 'SyncMailEnabledSecurityGroups', Mandatory = $false)]
		[string]$MailEnabledSecurityGroupsOU,
		[Parameter(ParameterSetName = 'SyncSecurityGroups')]
		[switch]$SyncSecurityGroups,
		[Parameter(ParameterSetName = 'SyncSecurityGroups', Mandatory = $false)]
		[string]$SecurityGroupsOU
	)
	Write-Host "Checking to see if MSOnline Module is present" -ForegroundColor Green
	$MSOnlineCheck = get-module | Where-object { $_.name -like "*msonline*" }
	If ($Null -eq $MSOnlineCheck)
	{
		Write-Warning "MSOnline module is not present, attempting to install it"
		Install-Module Msonline -Force
		
	}
	Write-Host "Importing MSOnline Module"
	Import-Module MSOnline
	function Connect-O365
	{
		$UserCredential = Get-Credential
		$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://ps.outlook.com/powershell/" -Credential $UserCredential -Authentication Basic -AllowRedirection
		Import-PSSession $Session
		Connect-MsolService -Credential $UserCredential
	}
	
	
	#Connect-O365
	
	Write-Host "###############################" -ForegroundColor Green
	Write-Host "#         DOMAINS             #" -ForegroundColor Green
	Write-Host "###############################" -ForegroundColor Green
	
	#Get all domains in Office 365 tenant, do not grab the onmicrosoft domain. Add all the Domains as valid UPN suffixes in AD
	$Domains = Get-MsolDomain | Where-Object { $_.Name -notlike "*.onmicrosoft.com*" } | Select-Object -ExpandProperty Name
	foreach ($Domain in $Domains)
	{
		Write-Host "Adding $Domain as a valid UPN suffix"
		#If the UPN suffix is already present it will not error or cause issues
		Get-ADForest | Set-ADForest -UPNSuffixes @{ add = "$Domain" }
	}
	If ($SyncUsers -eq $true)
	{
		Write-Host "###############################" -ForegroundColor Green
		Write-Host "#          USERS              #" -ForegroundColor Green
		Write-Host "###############################" -ForegroundColor Green
		
		$Password = ConvertTo-SecureString $Passwordforallusers -AsPlainText -Force
		
		#Get all of the Office 365 Users
		#Conditional to remove the account AADConnect will use. You will see this account synced if Office 365 was previously synced to Office 365. This account will be created automatically when you use express settings in the AADConnect wizard
		$Users = Get-Msoluser -All | Where-Object { $_.DisplayName -notlike "On-Premises Directory Synchronization Service Account" }
		foreach ($User in $Users)
		{
			Write-Host "Working on the user, '$($User.DisplayName)'" -ForegroundColor Green
			
			Write-Host "Storing the user in a var"
			$ADUser = Get-ADUser -Filter * | Where-Object { $_.Name -eq $user.DisplayName } -ErrorAction SilentlyContinue
			Write-Host "Checking to see if $($user.displayname) is already present in Active Directory"
			If ($Null -ne $ADUser)
			{
				write-host "$($user.displayname) is present in Active Directory, Skipping!"
			}
			Else
			{
				
				write-host "$($user.displayname) is not present in Active Directory"
				
				
				Write-Host "Working on $($User.DisplayName)..." -ForegroundColor Yellow
				
				#Var for priamry e-mail address
				$PrimEMail = Get-MSOLUser -UserPrincipalName $user.UserPrincipalName | Select-Object -ExpandProperty ProxyAddresses | Where-Object { $_ -cmatch '^SMTP:' }
				#Var for all the alias e-mail addresses
				$AliasEMails = Get-MSOLUser -UserPrincipalName $user.UserPrincipalName | Select-Object -ExpandProperty ProxyAddresses | Where-Object { $_ -cmatch 'smtp:' }
				
				$SamAccountName = $user.UserPrincipalName.split("@") | Select-Object -First 1
				
				Write-Host "Creating the user, '$($User.DisplayName)' as an Active Directory user... "
				If ($Null -ne $PrimEMail)
				{
					
					New-ADUser -Name $User.DisplayName -GivenName $user.Firstname -Surname $user.LastName -userprincipalName $user.UserPrincipalName -EmailAddress $PrimEMail.replace("SMTP:", "") -Enabled $true -AccountPassword $Password -ChangePasswordAtLogon $true -SamAccountName $SamAccountName -DisplayName $User.DisplayName -Office $User.Office -Title $User.Title -Department $User.Department -City $User.City -OfficePhone $User.PhoneNumber
				}
				Else
				{
					New-ADUser -Name $User.DisplayName -GivenName $user.Firstname -Surname $user.LastName -userprincipalName $user.UserPrincipalName -Enabled $true -AccountPassword $Password -ChangePasswordAtLogon $true -SamAccountName $SamAccountName -DisplayName $User.DisplayName -Office $User.Office -Title $User.title -Department $User.Department -City $User.City -OfficePhone $User.PhoneNumber
					
				}
				$ADUser = Get-ADUser -Filter * | Where-Object { $_.Name -eq $user.DisplayName } -ErrorAction SilentlyContinue
				#Add all the proxy e-mail address to the user
				foreach ($AliasEMail in $AliasEMails)
				{
					Write-Host "Adding the alias $AliasEMail for user, '$($User.DisplayName)'"
					$ADUser | Set-ADUser -Add @{ Proxyaddresses = "$AliasEMail" }
				}
				
				#Set the primary e-mail address
				Write-Host "Adding the primary email address $PrimEMail for $($User.DisplayName)"
				$ADUser | Set-ADUser -Add @{ Proxyaddresses = "$PrimEMail" }
				
			}
			
			If ($UsersOU -like "*OU*")
			{
				Write-Host "Moving the user, '$($User.DisplayName)' to the OU at $UsersOU"
				Move-ADObject -Identity $ADUser.ObjectGuid -TargetPath $UsersOU
			}
			
			
			$ADUser = $null
		}
	}
	
	If ($SyncContacts -eq $true)
	{
		
		Write-Host "###############################" -ForegroundColor Green
		Write-Host "#        CONTACTS             #" -ForegroundColor Green
		Write-Host "###############################" -ForegroundColor Green
		
		#Mail Contacts
		$MailContacts = Get-MailContact
		Foreach ($MailContact in $MailContacts)
		{
			$mailcontactexternalemail = ($mailcontact.ExternalEmailAddress).split("SMTP:") | Select-Object -Last 1
			$Mailcontactfirstname = ($MailContact.displayname).split() | Select-Object -First 1
			$Mailcontactlastname = ($MailContact.displayname).split() | Select-Object -Last 1
			
			Write-Host "Working on the contact , '$($MailContact.displayname)'" -ForegroundColor Green
			
			$EContactUser = Get-ADObject -LDAPFilter "objectClass=Contact" | Where-Object { $_.Name -eq $mailcontact.DisplayName } -ErrorAction SilentlyContinue
			If ($Null -ne $EContactUser)
			{
				write-host "$($MailContact.displayname) is present in Active Directory, Skipping!"
			}
			Else
			{
				
				Write-Host "$($MailContact.displayname) not found in Active Directory, creating..."
				
				Write-Host "Creating mail contact, '$($Mailcontact.DisplayName)'" -ForegroundColor Yellow
				New-ADObject -name $mailcontact.displayname -DisplayName $mailcontact.displayname -type contact -OtherAttributes @{ 'mail' = $mailcontactexternalemail; 'givenName' = $Mailcontactfirstname; 'sn' = $Mailcontactlastname; }
			}
			$EContactUser = Get-ADObject -LDAPFilter "objectClass=Contact" | Where-Object { $_.Name -eq $mailcontact.DisplayName } -ErrorAction SilentlyContinue
			If ($ContactsOU -like "*OU*")
			{
				Write-Host "Moving the contact, '$($MailContact.displayname)' to $ContactsOU"
				Move-ADObject $EContactUser.ObjectGuid -TargetPath $ContactsOU
			}
			
			
			$EContactUser = $null
		}
	}
	
	If ($SyncDistributionGroups -eq $true)
	{
		
		Write-Host "###############################" -ForegroundColor Green
		Write-Host "#     DISTRIBUTION GROUPS     #" -ForegroundColor Green
		Write-Host "###############################" -ForegroundColor Green
		
		#Distribution Groups
		$Groups = Get-DistributionGroup | Where-Object { $_.GroupType -eq "Universal" }
		foreach ($Group in $Groups)
		{
			
			Write-Host "Working on the Distribution Group, '$($Group.DisplayName)'" -ForegroundColor Green
			Write-Host "Checking to see if the Distribution Group, '$($Group.DisplayName) is already present in Active Directory'"
			Try { Get-ADGroup -Identity $Group.DisplayName -ErrorAction SilentlyContinue }
			Catch
			{
				Write-Host "The Distribution Group, '$($Group.DisplayName) is not present in Active Directory'" -ForegroundColor Yellow
				$GroupSAMAccountName = ($Group.DisplayName).Trim(" ")
				Write-Host "Creating the Distribution group, '$($group.DisplayName)'"
				If ($DistributionGroupsOU -like "*OU*")
				{
					New-ADGroup -Name $Group.DisplayName -SamAccountName $GroupSAMAccountName -GroupCategory "Distribution" -GroupScope Global -DisplayName $Group.DisplayName -Path $DistributionGroupsOU -OtherAttributes @{ 'mail' = $group.PrimarySmtpAddress } -Description $Group.Description
				}
				Else
				{
					New-ADGroup -Name $Group.DisplayName -SamAccountName $GroupSAMAccountName -GroupCategory "Distribution" -GroupScope Global -DisplayName $Group.DisplayName -OtherAttributes @{ 'mail' = $group.PrimarySmtpAddress } -Description $Group.Description
					
				}
			}
			Write-Host "Getting members for Distribution group, '$($Group.DisplayName)'"
			$Members = Get-DistributionGroupMember -Identity $Group.Name
			If ($Null -eq $Members)
			{
				write-host "$($Group.displayname) Has no members to add, Skipping!"
			}
			Else
			{
				foreach ($Member in $Members)
				{
					Write-Host "Adding $($Member.Name) to the group, '$($Group.Name)'"
					
					$AddMember = Get-ADObject -Filter * | Where-Object { $_.Name -eq $member.DisplayName }
					
					Set-ADGroup -identity $Group.DisplayName -add @{ 'member' = $AddMember.DistinguishedName }
					
				}
			}
			$GroupPresent = $null
		}
	}
	
	If ($SyncMailEnabledSecurityGroups -eq $true)
	{
		
		Write-Host "################################" -ForegroundColor Green
		Write-Host "# MAIL-ENABLED SECURITY GROUPS #" -ForegroundColor Green
		Write-Host "################################" -ForegroundColor Green
		
		#Mail Enabled Security Groups
		$MailEnabledSecurityGroups = Get-DistributionGroup | Where-Object { $_.GroupType -like "*SecurityEnabled*" }
		foreach ($MailEnabledSecurityGroup in $MailEnabledSecurityGroups)
		{
			
			Write-Host "Working on the mail-enabled security group, '$($MailEnabledSecurityGroup.DisplayName)'" -ForegroundColor Green
			
			Write-Host "Checking to see if the Mail-Enabled Security Group, '$($MailEnabledSecurityGroup.DisplayName) is already present in Active Directory'"
			Try { Get-ADGroup -Identity $MailEnabledSecurityGroup.DisplayName }
			Catch
			{
				Write-Host "The Mail-Enabled Security Group, '$($MailEnabledSecurityGroup.DisplayName) is not present in Active Directory'" -ForegroundColor Yellow
				
				$GroupSAMAccountName = ($MailEnabledSecurityGroup.DisplayName).Trim(" ")
				Write-Host "Creating the Mail-Enabled Security group, '$($MailEnabledSecurityGroup.DisplayName)'"
				If ($MailEnabledSecurityGroupsOU -like "*OU*")
				{
					New-ADGroup -Name $MailEnabledSecurityGroup.DisplayName -SamAccountName $GroupSAMAccountName -GroupCategory "Security" -GroupScope Global -DisplayName $MailEnabledSecurityGroup.DisplayName -Path $MailEnabledSecurityGroupsOU -OtherAttributes @{ 'mail' = $MailEnabledSecurityGroup.PrimarySmtpAddress } -Description $MailEnabledSecurityGroup.Description
				}
				Else
				{
					New-ADGroup -Name $MailEnabledSecurityGroup.DisplayName -SamAccountName $GroupSAMAccountName -GroupCategory "Security" -GroupScope Global -DisplayName $MailEnabledSecurityGroup.DisplayName -OtherAttributes @{ 'mail' = $MailEnabledSecurityGroup.PrimarySmtpAddress } -Description $MailEnabledSecurityGroup.Description
					
				}
			}
			Write-Host "Getting members for the Mail-Enabled Security group, '$($MailEnabledSecurityGroup.DisplayName)'"
			$Members = Get-DistributionGroupMember -Identity $MailEnabledSecurityGroup.Name
			foreach ($Member in $Members)
			{
				Write-Host "Adding $($Member.Name) to the group, '$($MailEnabledSecurityGroup.Name)'"
				
				$AddMember = Get-ADObject -Filter * | Where-Object { $_.Name -eq $member.DisplayName }
				
				Set-ADGroup -identity $MailEnabledSecurityGroup.DisplayName -add @{ 'member' = $AddMember.DistinguishedName }
				
				
			}
			$GroupPresent = $null
		}
	}
	
	If ($SyncSecurityGroups -eq $true)
	{
		
		
		Write-Host "################################" -ForegroundColor Green
		Write-Host "#       SECURITY GROUPS        #" -ForegroundColor Green
		Write-Host "################################" -ForegroundColor Green
		
		#Mail Enabled Security Groups
		#I have a lot of conditionals in there. These groups are default AD groups that may have been synced to Office 365 if someone configured it with the express settings. Using these conditionals I am exluding these groups because they already exisit or will exisit when you set up AADConnect
		$SecurityGroups = Get-MsolGroup | Where-Object { ($_.GroupType -eq "Security") -and ($_.DisplayName -notlike "ADSyncOperators") -and ($_.DisplayName -notlike "ADSyncBrowse") -and ($_.DisplayName -notlike "ADSyncOperators") -and ($_.DisplayName -notlike "ADSyncPasswordSet") -and ($_.DisplayName -notlike "ADSyncAdmins") -and ($_.DisplayName -notlike "DnsAdmins") -and ($_.DisplayName -notlike "DnsUpdateProxy") }
		foreach ($SecurityGroup in $SecurityGroups)
		{
			
			Write-Host "Working on the security group, '$($SecurityGroup.DisplayName)'"
			
			Write-Host "Checking to see if the Mail-Enabled Security Group, '$($SecurityGroup.DisplayName) is already present in Active Directory'"
			Try { Get-ADGroup -Identity $SecurityGroup.DisplayName }
			Catch
			{
				Write-Host "The Security Group, '$($SecurityGroup.DisplayName) is not present in Active Directory'" -ForegroundColor Yellow
				
				$GroupSAMAccountName = ($SecurityGroup.DisplayName).Trim(" ")
				Write-Host "Creating the Security group, '$($SecurityGroup.DisplayName)'"
				If ($UsersOU -like "*OU*")
				{
					New-ADGroup -Name $SecurityGroup.DisplayName -SamAccountName $GroupSAMAccountName -GroupCategory "Security" -GroupScope Global -DisplayName $SecurityGroup.DisplayName -Path $SecurityGroupsOU -Description $SecurityGroup.Description
				}
				Else
				{
					New-ADGroup -Name $SecurityGroup.DisplayName -SamAccountName $GroupSAMAccountName -GroupCategory "Security" -GroupScope Global -DisplayName $SecurityGroup.DisplayName -Description $SecurityGroup.Description
					
				}
			}
			Write-Host "Getting members for the Security group, '$($SecurityGroup.DisplayName)'"
			$Members = Get-MsolGroupMember -GroupObjectId $SecurityGroup.ObjectID
			foreach ($Member in $Members)
			{
				Write-Host "Adding $($Member.DisplayName) to the group, '$($SecurityGroup.DisplayName)'"
				
				$AddMember = Get-ADObject -Filter * | Where-Object { $_.Name -eq $member.DisplayName }
				
				Set-ADGroup -identity $SecurityGroup.DisplayName -add @{ 'member' = $AddMember.DistinguishedName }
				
				
			}
		}
	}
}

