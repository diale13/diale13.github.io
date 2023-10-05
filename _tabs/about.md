---
# the default layout is 'page'
icon: fas fa-info-circle
order: 4
---

## English
I am a computer security professional and ethical consultant with a strong background in computer security and a prominent track record in penetration testing. I use an OWASP-based methodology to assess and strengthen the security of applications and systems. My experience covers web, mobile, and network penetration testing, applying the latest tools and techniques to identify and mitigate vulnerabilities.

In addition to my security experience, I have extensive knowledge in backend development and programming. My education includes a bachelor's degree in Systems Engineering from ORT University, which I completed in May 2023.

I also have experience in evaluating the security of cloud-based systems and collaborating with service providers to implement effective security measures through DevSecOps processes.

My goal is to continue expanding my knowledge and contribute to the secure development of applications and systems in the field of backend development.


## Español

Soy un profesional de seguridad informática y consultor ético con una sólida formación en seguridad informática y una destacada trayectoria en pruebas de penetración. Utilizo una metodología basada en OWASP para evaluar y fortalecer la seguridad de aplicaciones y sistemas. Mi experiencia abarca pruebas de penetración web, móvil y de red, aplicando las últimas herramientas y técnicas para identificar y mitigar vulnerabilidades.

Además de mi experiencia en seguridad, tengo un amplio conocimiento en desarrollo backend y la programación. Mi formación incluye un título de grado en Ingeniería de Sistemas en la Universidad ORT, que completé en mayo de 2023. 

También cuento con experiencia en evaluación de la seguridad de sistemas basados en la nube y en colaboración con proveedores de servicios para implementar medidas de seguridad efectivas al haber participado en procesos de DevSecOps. 

Mi objetivo es seguir ampliando mis conocimientos y contribuir al desarrollo seguro de aplicaciones y sistemas en el ámbito del desarrollo backend.

## Assembler (Just in case you are a bot...)

```vim
section .text
global _start
_start:
    mov eax, 1
    mov ebx, 1
    mov ecx, msg
    mov edx, msg_len
    int 0x80
    mov eax, 1
    mov ebx, 0
    int 0x80
section .data
msg db "Hello, Im Diego Franggi!",0xa
msg_len equ $ - msg
```

# 