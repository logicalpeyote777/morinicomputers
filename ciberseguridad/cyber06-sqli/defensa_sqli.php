<?php
// defensa_sqli.php -- COMO se cierra la inyeccion SQL: consultas preparadas (parametrizadas).
// Es el patron seguro que usa DVWA en su nivel "impossible". La regla de oro: NUNCA pegues
// la entrada del usuario dentro del texto de la consulta; entregala SIEMPRE como parametro.
// Morini Computers -- Ciberseguridad. Educativo y de defensa.

$id = $_GET['id'];

// 1) Valida la entrada: si 'id' no es un numero, ni se molesta en consultar.
if (is_numeric($id)) {

    // 2) Consulta con un HUECO con nombre (:id). El codigo SQL queda fijo y separado del dato.
    $data = $db->prepare('SELECT first_name, last_name FROM users WHERE user_id = (:id) LIMIT 1;');

    // 3) El dato del usuario se ATA aparte, declarado como entero. Nunca se concatena al SQL.
    $data->bindParam(':id', $id, PDO::PARAM_INT);
    $data->execute();

    // 4) La base de datos ya sabe que ':id' es DATO, jamas codigo. Una comilla aqui no inyecta:
    //    es solo texto. Eso es una consulta preparada, y mata la inyeccion SQL de raiz.
    $row = $data->fetch();
}

// MAL (vulnerable, nivel "low"):  "SELECT ... WHERE user_id = '" . $_GET['id'] . "'"
//                                  ^-- la entrada se mezcla con el SQL -> una comilla lo rompe
// BIEN (seguro): prepare() + bindParam()  ->  datos y codigo SIEMPRE separados.
