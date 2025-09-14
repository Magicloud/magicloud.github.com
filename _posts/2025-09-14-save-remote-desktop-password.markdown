---
layout: post
title:  "Save Remote Desktop Password"
date:   2025-09-14 17:33:17 +0800
categories: Windows
---
For reason unknown, the Remote desktop app of my Windows 11 does not give the saving credentials option. After I switched to a longer password length, this is urgenly a problem.

On the first try, I updated the Group Policy, which equals to registry below. The option appeared, I could input the password before connecting. But it did not pass, nor it was saved.

```
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services]
"DisablePasswordSaving"=dword:00000000

[HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\CredentialsDelegation]
"AllowDefaultCredentials"=dword:00000001
"AllowDefaultCredentialsWhenNTLMOnly"=dword:00000001
"ConcatenateDefaults_AllowDefault"=dword:00000001
"AllowSavedCredentials"=dword:00000001
"ConcatenateDefaults_AllowSaved"=dword:00000001
"AllowSavedCredentialsWhenNTLMOnly"=dword:00000001
"ConcatenateDefaults_AllowSavedNTLMOnly"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowDefaultCredentials]
"1"="TERMSRV/*"

[HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowSavedCredentials]
"1"="TERMSRV/*"

[HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowSavedCredentialsWhenNTLMOnly]
"1"="TERMSRV/*"

[HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowDefaultCredentialsWhenNTLMOnly]
"1"="TERMSRV/*"
```

Then I decided to update the .rdp file directly. Much simpler. The tool involves is [a powershell script](https://github.com/RedAndBlueEraser/rdp-file-password-encryptor). Run the encryptor, input the password, append a line to .rdp file in format of `password 51:b:**YOUR HEXADECIMAL STRING HERE**`. And that is it. Note: the encrypting is host depended. Using the same "hexadecimal string" on other hosts won't work.