INSERT INTO task_status (name) 
VALUES
('To do'),
('Assigned'),
('In progress'),
('Overdue'),
('Done');

INSERT INTO task_types (name) 
VALUES
('Watering'),
('Thin'),
('Scout pest');
('Planting');

INSERT INTO beds (size) 
VALUES
(10),
(16),
(12);

INSERT INTO units (unit) 
VALUES
('g'),
('kg'),
('pcs'),
('ton');

INSERT INTO suppliers (name, address, zip, city, phone) 
VALUES
('Jardinerie de Tourbillon', 'Rue de Tourbillon 5', '1950', 'Sion', '027 456 12 78'),
('Jardinerie de Valère', 'Rue de Valère 18', '1950', 'Sion', '027 123 78 45');

INSERT INTO users (pwd, username, first_name, last_name, active)
VALUES
('chaton1234', 'Jeanine', 'Jeanine', 'Matter', true),
('Miz3rab1e', 'Jeannot', 'Jean', 'Valjean', true),
('coe(è0£tç^5e7', 'TheGardener', 'Aristides', 'Madina', true);

INSERT INTO items (name, supplier_id, unit_id)
VALUES
('Concombre Serpent de Chine', 1, 1),
('Carotte Purple Haze', 2, 1),
('Chou-fleur Romanesco', 2, 1),
('Navet de Milan rouge', 1, 1),
('Engrais', 2, 2),
('Désherbant', 1, 2);

INSERT INTO crops (item_id, variety, watering_interval, harvesting_window, thin_interval, scout_pest_interval)
VALUES
(1, 'Concombre Serpent de Chine', 1, 100, 100, 5),
(2, 'Carotte Purple Haze', 1, 14, 14, 3),
(3, 'Chou-fleur Romanesco', 2, 90, 90, 5),
(4, 'Navet de Milan rouge', 2, 60, 60, 5);

INSERT INTO stocks (item_id, stock_movement)
VALUES
(1, 1000),
(2, 1000),
(3, 1000),
(4, 1000),
(5, 450),
(6, 250),
(2, 800),
(3, 500),
(1, -80),
(1, -120),
(4, -110),
(5, -12),
(5, -20);

INSERT INTO plantings (bed_id, crop_id, harvesting_date, is_trial, size)
VALUES
(1, 1, CURRENT_DATE + INTERVAL '100 DAY', false, 5),
(1, 2, CURRENT_DATE + INTERVAL '14 DAY', false, 5),
(2, 3, CURRENT_DATE + INTERVAL '90 DAY', false, 8),
(2, 4, CURRENT_DATE + INTERVAL '60 DAY', true, 8);

INSERT INTO notes (planting_id, text)
VALUES
(4, 'Jour 1, tout se passe bien'),
(4, 'Jour 2, quelque chose semble bizarre, mais ce n''est probablement pas grave.'),
(4, 'Jour 16, les plantes me parlent, venez me chercher s''il vous plait.');

INSERT INTO tasks (type_id, user_id, planting_id, due)
VALUES
(1, 1, 1, CURRENT_DATE + INTERVAL '1 DAY'),
(1, 1, 1, CURRENT_DATE + INTERVAL '2 DAY'),
(1, 2, 1, CURRENT_DATE + INTERVAL '3 DAY'),
(1, 2, 1, CURRENT_DATE + INTERVAL '4 DAY'),
(1, 3, 2, CURRENT_DATE + INTERVAL '1 DAY'),
(1, 3, 2, CURRENT_DATE + INTERVAL '2 DAY'),
(1, 3, 2, CURRENT_DATE + INTERVAL '3 DAY'),
(1, NULL, 3, CURRENT_DATE + INTERVAL '4 DAY'),
(1, NULL, 3, CURRENT_DATE + INTERVAL '5 DAY'),
(1, NULL, 3, CURRENT_DATE + INTERVAL '6 DAY'),
(2, NULL, 3, CURRENT_DATE + INTERVAL '4 DAY'),
(3, NULL, 3, CURRENT_DATE + INTERVAL '5 DAY'),
(4, NULL, 3, CURRENT_DATE + INTERVAL '6 DAY');

INSERT INTO task_materials (task_id, item_id, qty)
VALUES
(8, 6, 1),
(9, 6, 2),
(10, 6, 1);