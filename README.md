# Sync-Office365ToADDS
Copies Office 365 (AzureAD) objects down to ADDS. 

The PowerShell function will connect to your Office 365 / AzureAD and can re-create your Users, Groups, and Contacts in Active Directory. 
		This is extremly helpful if you are looking to change your identity source from Office 365 (AzureAD) to Active Directory and then have Active Directory sync up to Office 365.
		This will also re-create Distribution, Security, and Mail-Enabled Security Groups and also populate the membership and owner (managed by). Distribution and Mail-Enabled security groups will SMTP match when you configure AADConnect.

### Users
- First Name
- Last Name
- Display Name
- User Principal Name
- Email Address
- Proxy Addresses
  - SMTP
  - SPO
  -   SIP
  -   EUM
- Office
- Title
- Department
- City
- Office Phone (telephone number)
### Contacts
- Display Name
- External Email
- Proxy Addresses
- First Name
- Last Name
### Distribution Groups
- Name
- Display Name
- Primary SmtpAddress
- Proxyaddresses
- Description
- Members
- Group Owner (Managed By)
### Mail-Enabled Security Groups
- Name
- Display Name
- Primary SmtpAddress
- Description
- Members
- Group Owner (Managed By)
### Security Groups
- Name
- Display Name
- Primary SmtpAddress
- Description
- Members
- Group Owner (Managed By)
