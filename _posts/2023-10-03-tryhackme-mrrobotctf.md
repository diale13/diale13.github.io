---
toc: true
comments: true
title: TryHackMe - MrRobot CTF
layout: post
title: TryHackMe - MrRobotCTF
date: 2023-10-03 20:45 -0300
categories: [TryHackMe, Medium, CTF]
tags: [Wordpress, PrivEsc]    
image: /assets/Posts/MrRobot/1_Teaser.png
---

## Enumeracion
Comenzamos con un escaneo de puertos utilizando nmap.
Haremos el siguiente escaneo que, pese a no ser el mas complejo, nos dara resultados mas rapidos. 

```bash
nmap -p- --open -sS -Pn --min-rate 5000 -v -n 10.10.253.9
```

