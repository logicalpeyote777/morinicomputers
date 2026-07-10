CREATE TABLE IF NOT EXISTS facturas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  cliente  VARCHAR(50),
  concepto VARCHAR(60),
  importe  DECIMAL(8,2)
);
INSERT INTO facturas (cliente, concepto, importe) VALUES
  ('Talleres Ruiz SL',        'Migracion VMware a Proxmox', 3200.00),
  ('Clinica Dental Sonrisa',  'Servidor + backups',         2850.50),
  ('Asesoria Gomez',          'Mantenimiento anual IT',     2900.00);
