<?php
// defensa_web.php - como se ARREGLA la inyeccion SQL (el ejemplo del video).
// La diferencia entre una web que te roban y una segura son 2 lineas.

// ---- MAL: VULNERABLE ----------------------------------------------------
// Se pega la entrada del usuario DENTRO del SQL (concatenacion de textos).
// El usuario puede cerrar la comilla y escribir SU propia consulta -> inyeccion.
$id  = $_GET['id'];
$sql = "SELECT first_name, last_name FROM users WHERE user_id = '$id'";
$res = mysqli_query($conn, $sql);

// ---- BIEN: CONSULTA PREPARADA (sentencia parametrizada) -----------------
// El SQL y los datos viajan POR SEPARADO: la entrada nunca se ejecuta como codigo.
$stmt = $pdo->prepare('SELECT first_name, last_name FROM users WHERE user_id = ?');
$stmt->execute([ $_GET['id'] ]);   // el ? se rellena como DATO, jamas como SQL
$res  = $stmt->fetchAll();

// ---- DEFENSA EN CAPAS (no te quedes solo en lo de arriba) ---------------
//   1) Consultas preparadas SIEMPRE, en cada consulta a la base de datos.
//   2) Usuario de BBDD con privilegios MINIMOS (solo su tabla; sin FILE ni GRANT).
//   3) Contrasenas con hashing FUERTE + sal (bcrypt / argon2), NUNCA MD5 pelado.
//   4) WAF delante, software actualizado y errores genericos (no reveles el fallo).
