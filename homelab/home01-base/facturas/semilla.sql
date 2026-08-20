CREATE TABLE facturas (
  id       serial PRIMARY KEY,
  cliente  text,
  concepto text,
  importe  numeric(10,2),
  iban     text
);
INSERT INTO facturas (cliente, concepto, importe, iban) VALUES
 ('Panaderia La Espiga SL',  'Mantenimiento servidor',   1250.00, 'ES00 0000 0000 0000 0000 0001'),
 ('Talleres Nuevo Norte SL', 'Migracion de correo',      3480.50, 'ES00 0000 0000 0000 0000 0002'),
 ('Clinica Dental Aurora',   'Copias de seguridad 2026', 2199.00, 'ES00 0000 0000 0000 0000 0003'),
 ('Gestoria Cabo Verde SL',  'Servidor de ficheros',     5750.75, 'ES00 0000 0000 0000 0000 0004');
