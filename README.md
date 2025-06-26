# Ejecuta Litd

![Alt text](litd.png "Ejecuta Litd")

Notas y scripts de ayuda para configurar y ejecutar un nodo Litd.

Esta versión en español es un fork actualizado del trabajo de [@HannahMR](https://github.com/HannahMR/run-litd). Gracias por ser tan clara!
Y se inspira en el repositorio [Alex Bosworth](https://github.com/alexbosworth/run-lnd/). Allí puede encontrar información más detallada sobre la configuración de un nodo Lightning.

¡Importante!: Estos ejemplos y scripts están diseñados para ayudar a los desarrolladores a configurar todo rápidamente para comenzar las pruebas y el desarrollo de aplicaciones. Por favor, no confíe en estos archivos para su entorno de producción.

Puede ver un video en inglés de demostración de estos scripts [aquí](https://www.youtube.com/watch?v=lopHP_nF0tE)

## Contenido

1. [Instrucciones](https://github.com/Foxtrot-Zulu/ejecuta-litd/#instrucciones)
2. [Requisitos del Servidor](https://github.com/Foxtrot-Zulu/ejecuta-litd/#Requisitos-del-Servidor)
3. [Preparación del Servidor](https://github.com/Foxtrot-Zulu/ejecuta-litd/#Preparación-del-Servidor)
4. [Configuración de Bitcoind](https://github.com/Foxtrot-Zulu/ejecuta-litd/#Configuración-de-Bitcoind)
5. [Configuración de Litd](https://github.com/Foxtrot-Zulu/ejecuta-litd/#Configuración-de-Litd)

## Instrucciones

Esta guía contiene listas de verificación, archivos de ejemplo y scripts de ayuda para poner en funcionamiento un nodo Litd en un servidor Ubuntu. Estos scripts se han probado en Ubuntu 24.04. Hay tres secciones principales en la guía: preparación del servidor, configuración de bitcoind y configuración de litd. En cada una de estas secciones encontrará una descripción de lo que debe suceder, una lista de verificación a seguir, enlaces a archivos de ejemplo y, si lo prefiere, scripts bash que ejecutarán las listas de verificación por usted.

Las versiones actuales de estas listas de verificación y scripts instalan...

- bitcoind v29.0
- litd v0.14.0-alpha

## Requisitos del Servidor

Esta configuración está bien testeada en servidores Ubuntu con al menos este nivel de recursos:

- 2+ Núcleos de CPU
- 80GB+ de Almacenamiento (nodo podado)
- 4GB+ de RAM

Deberá aumentar estos recursos cuando ejecute un servidor de producción o cuando ejecute un nodo completo.

## Clonar el Repositorio

Para tener acceso a los scripts de bash y demás archivos, puede clonar este repositorio dentro del nuevo servidor.

```git clone https://github.com/Foxtrot-Zulu/ejecuta-litd.git```

## Preparación del Servidor

Este paso prepara el servidor. Se crea un nuevo usuario de Ubuntu con acceso sudo. Se agregan claves SSH. La seguridad se refuerza deshabilitando el inicio de sesión de root y la autenticación por contraseña. Después de ejecutarlo, deberá iniciar sesión en el servidor como el usuario de Ubuntu a través de SSH.

Este paso se puede realizar de forma manual siguiendo el archivo de la lista de verificación que se encuentra en [/checklists/server-setup-checklist.txt](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/checklists/server-setup-checklist.txt) o ejecutando el script bash de configuración automática en [/scripts/server_setup.sh](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/scripts/server_setup.sh)

### Script de Ayuda para la Preparación del Servidor

Se le pedirá que pegue las claves SSH de su equipo a medida que se ejecuta el script.

Ingresar a la carpeta ~/ejecutadel repositorio que se clonó.
```$ cd ~/ejecuta-litd/scripts```

No olvide hacerlo ejecutable antes de intentar ejecutarlo.

```$ chmod +x server_setup.sh```

El script debe ejecutarse con sudo. No se preocupe, los repositorios, archivos, etc. serán propiedad de su usuario actual (un nuevo usuario llamado "ubuntu" si se utilizó el script server_setup).

```$ sudo ./server_setup.sh```

Cuando el script pida la clave SSH, debe generarla dentro de la terminal de su computadora -no en el nuevo servidor-, con estos comandos:

```$ ssh-keygen -t ed25519 -C "tu_email@ejemplo.com"```

Le pedirá una ubicación para guardar las claves, solo presione Enter para que las guarde con el nombre y en el directorio por defecto: /home/tu_usuario/.ssh/id_ed25519.
Luego le pedirá de forma opcional una passphrase, que en entornos de test puede obviarse. Una vez completado mostrará algo similar a esto:

```
Your identification has been saved in /home/tu_usuario/.ssh/id_ed25519
Your public key has been saved in /home/tu_usuario/.ssh/id_ed25519.pub
The key's randomart image is:
+--[ED25519 256]--+
|      .+         |
|     B.          |
|    o. + .       |
|   .+ * * B      |
|  . + o S +      |
|   . o + =       |
|    E = B .      |
|     . = +       |
|      ...o.      |
+----[SHA256]-----+
```

Luego debe copiar la clave ssh y pegarla en la terminal donde está ejecutando el script server_setup.sh. Para eso, ir a la carpeta /home/tu_usuario/.ssh y ejecutar:

```$ cat id_ed25519.pub```


Toda la línea completa que se muestra es lo que se debe copiar y pegar en el servidor. Ej: 

```ssh-ed25519 AAA1lZDI1NTEAAAIHOO7upjhjrW0a3obS47upjhjrW0a/LB usuario@mail.com```

Si originalmente clonó el repositorio con el usuario root, es posible que desee mover el repositorio ejecuta-litd al directorio de inicio del nuevo usuario de Ubuntu y luego transferir la propiedad.

```$ sudo mv ~/NOMBRE_DE_USUARIO/ejecuta-litd/ /home/ubuntu/ejecuta-litd/```

```$ sudo chown -R ubuntu:ubuntu /home/ubuntu/ejecuta-litd/```

## Configuración de Bitcoind

Este paso instala y ejecuta bitcoind. El servidor se actualiza, se instalan las dependencias de bitcoind, se compila bitcoind o se descarga el binario, se crea un archivo de configuración, se crea un archivo .service de systemd y se ejecuta bitcoind. Aquí hay dos scripts y listas de verificación. Uno para compilar desde la fuente y otro para descargar un binario.

A medida que se ejecutan los scripts, se le pedirá que seleccione la red: signet o mainnet.

Este paso se puede realizar siguiendo el archivo de la lista de verificación que se encuentra aquí [/checklists/bitcoind-setup-checklist.txt](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/checklists/bitcoind-setup-checklist.txt) y aquí [/checklists/bitcoind-setup-binary-checklist.txt](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/checklists/bitcoind-setup-binary-checklist.txt) o ejecutando uno de los scripts bash de configuración aquí [/scripts/bitcoind_setup.sh](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/scripts/bitcoind_setup.sh) o aquí [/scripts/bitcoind_setup_binary.sh](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/scripts/bitcoind_setup_binary.sh)

### Script de Ayuda para la Configuración de Bitcoind

Por favor, revise los valores predeterminados incluidos en el archivo de configuración de los scripts antes de ejecutar uno de los scripts. Los valores como la red, las contraseñas, etc. se seleccionarán/generarán cuando se ejecuten los scripts.

Aquí hay dos scripts para elegir, uno que instala desde la fuente, bitcoind_setup.sh, y otro que instala un binario, bitcoind_setup_binary.sh. Cualquiera que sea el script que elija, querrá ejecutarlo con el nuevo usuario que se creó en el proceso de configuración del servidor.

Estos scripts ejecutan de forma predeterminada un nodo podado, configurado en 50 GB. Si desea ejecutar un nodo completo o almacenar los datos de la cadena de bloques en un disco adjunto, deberá editar el script en consecuencia.

Al ejecutar un nodo completo en mainnet, el servidor debe tener al menos 800 GB. Es común utilizar un disco extra para toda la Blockchain. Cuando haga eso, deberá montar el disco y luego agregar una línea a su archivo bitcoin.conf.

```datadir=/ruta/al/directorio/de/almacenamiento```

Al ejecutar un nodo podado, la siguiente línea debe estar descomentada en el archivo bitcoin.conf.

```prune=50000 # Podar a 50GB```

Ambos scripts también ejecutan comprobaciones para ver lo que se ha hecho a medida que avanzan, por lo que deberían ser seguros para ejecutar varias veces en caso de que alguna ejecución se haya interrumpido.

Si originalmente clonó este repositorio en /root, es posible que desee moverlo a /home/ubuntu y cambiar el propietario para facilitar la ejecución.

No olvide hacer que los scripts sean ejecutables antes de intentar ejecutarlos.

```$ chmod +x bitcoind_setup.sh```

```$ chmod +x bitcoind_setup_binary.sh```

El script debe ejecutarse con sudo. No se preocupe, los repositorios, archivos, etc. serán propiedad de su usuario actual, (un nuevo usuario llamado "ubuntu" si se utilizó el script server_setup).

```$ sudo ./bitcoind_setup.sh```

```$ sudo ./bitcoind_setup_binary.sh```

## Configuración de Litd

Este paso instala y ejecuta litd. Al instalar desde la fuente, se instalan GoLang y NodeJS, se clona el repositorio y se compila litd. Al instalar desde el binario, se descargan los archivos apropiados, se genera un archivo lit.conf, se crea una billetera LND, se guarda la contraseña y se configura para desbloquearse automáticamente al inicio, se crea un archivo .service de systemd y se inicia litd.

La instalación de Litd se ve facilitada con este repositorio de varias maneras. Puede continuar con cualquiera de las opciones de configuración, la lista de verificación de instalación desde la fuente está aquí [/checklists/litd-setup-checklist.txt](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/checklists/litd-setup-checklist.txt) y la lista de verificación de instalación desde el binario está aquí [/checklists/litd-setup-binary-checklist.txt](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/checklists/litd-setup-binary-checklist.txt)

También se pueden utilizar los scripts bash para instalar desde la fuente o desde el binario. Para instalar desde la fuente, ejecute los scripts bash de configuración en [/scripts/litd_setup.sh](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/scripts/litd_setup.sh), [/scripts/litd_setup2.sh](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/scripts/litd_setup2.sh) y [/scripts/litd_setup3.sh](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/scripts/litd_setup3.sh)

Para instalar un binario, ejecute los scripts bash de configuración en [/scripts/litd_setup_binary.sh](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/scripts/litd_setup_binary.sh) y [/scripts/litd_setup3.sh](https://github.com/Foxtrot-Zulu/ejecuta-litd/blob/main/scripts/litd_setup3.sh)

### Script de Ayuda para la Configuración de Litd

Estos scripts ejecutan comprobaciones para ver lo que se ha hecho a medida que avanzan, por lo que deberían ser seguros para ejecutar varias veces en caso de que alguna ejecución se haya interrumpido.

Si está instalando desde la fuente, hay tres scripts para ejecutar aquí: litd_setup.sh, litd_setup2.sh y luego litd_setup3.sh. Deberá ejecutar el primer script y luego finalizar la sesión bash actual e iniciar una nueva antes de ejecutar el segundo. Deberá seguir el proceso de creación de la billetera después de ejecutar el script dos y antes del script tres.

Si está instalando el binario, hay dos scripts para ejecutar aquí: litd_setup_binary.sh y litd_setup3.sh. Después de ejecutar el script litd_setup_binary.sh, deberá seguir el proceso de creación de la billetera antes de ejecutar litd_setup3.sh.

No olvide hacerlos ejecutables antes de intentar ejecutarlos.

```$ chmod +x litd_setup*```

Los scripts deben ejecutarse con sudo. No se preocupe, los repositorios, archivos, etc. serán propiedad de su usuario actual (un nuevo usuario llamado "ubuntu" si se utilizó el script server_setup).

```$ sudo ./litd_setup.sh```

```$ sudo ./litd_setup_binary.sh```

```$ sudo ./litd_setup2.sh```

```$ sudo ./litd_setup3.sh```

Ahora a desarrollar! 

