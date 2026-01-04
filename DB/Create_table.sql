CREATE TABLE crops (
  id SERIAL PRIMARY KEY,
  item_id INTEGER NOT NULL,
  variety VARCHAR(100) NOT NULL,
  watering_interval INTEGER DEFAULT 1 CHECK (watering_interval >= 1),
  harvesting_window INTEGER DEFAULT 1 CHECK (harvesting_window >= 1),
  thin_interval INTEGER DEFAULT 1 CHECK (thin_interval >= 1),
  scout_pest_interval INTEGER DEFAULT 1 CHECK (scout_pest_interval >= 1)
);

CREATE TABLE plantings (
  id SERIAL PRIMARY KEY,
  bed_id INTEGER NOT NULL,
  crop_id INTEGER NOT NULL,
  planting_date DATE DEFAULT CURRENT_DATE,
  harvesting_date DATE,
  is_trial BOOL DEFAULT false,
  size INTEGER NOT NULL CHECK (size >= 1)
);

CREATE TABLE beds (
  id SERIAL PRIMARY KEY,
  size INTEGER NOT NULL CHECK (size >= 1)
);

CREATE TABLE notes (
  id SERIAL PRIMARY KEY,
  planting_id INTEGER NOT NULL,
  datetime TIMESTAMP DEFAULT LOCALTIMESTAMP ,
  text TEXT NOT NULL
);

CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  supplier_id INTEGER NOT NULL,
  unit_id INTEGER NOT NULL
);

CREATE TABLE suppliers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  address VARCHAR(100) NOT NULL,
  zip VARCHAR(10) NOT NULL,
  city VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  avg_delivery_time INTEGER
);

CREATE TABLE units (
  id SERIAL PRIMARY KEY,
  unit VARCHAR(100) NOT NULL
);

CREATE TABLE task_materials (
  id SERIAL PRIMARY KEY,
  task_id INTEGER NOT NULL,
  item_id INTEGER NOT NULL,
  qty INTEGER NOT NULL CHECK (qty != 0)
);

CREATE TABLE stocks (
  id SERIAL PRIMARY KEY,
  item_id INTEGER NOT NULL,
  stock_movement INTEGER NOT NULL CHECK (stock_movement != 0),
  datetime TIMESTAMP DEFAULT LOCALTIMESTAMP 
);

CREATE TABLE tasks (
  id SERIAL PRIMARY KEY,
  type_id INTEGER NOT NULL,
  user_id INTEGER,
  planting_id INTEGER,
  status_id INTEGER DEFAULT 1,
  due DATE NOT NULL CHECK (due >= CURRENT_DATE),
  start_time TIMESTAMP,
  end_time TIMESTAMP CHECK (end_time > start_time)
);

CREATE TABLE task_status (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL
);

CREATE TABLE task_types (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL
);

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  pwd VARCHAR(100) NOT NULL CHECK (CHAR_LENGTH(pwd) >= 8),
  username VARCHAR(100) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  active BOOL DEFAULT true
);

ALTER TABLE plantings
ADD FOREIGN KEY (crop_id) REFERENCES crops (id);

ALTER TABLE plantings
ADD FOREIGN KEY (bed_id) REFERENCES beds (id);

ALTER TABLE notes
ADD FOREIGN KEY (planting_id) REFERENCES plantings (id);

ALTER TABLE tasks
ADD FOREIGN KEY (planting_id) REFERENCES plantings (id);

ALTER TABLE crops
ADD FOREIGN KEY (item_id) REFERENCES items (id);

ALTER TABLE stocks
ADD FOREIGN KEY (item_id) REFERENCES items (id);

ALTER TABLE task_materials
ADD FOREIGN KEY (item_id) REFERENCES items (id);

ALTER TABLE tasks
ADD FOREIGN KEY (status_id) REFERENCES task_status (id);

ALTER TABLE tasks
ADD FOREIGN KEY (type_id) REFERENCES task_types (id);

ALTER TABLE task_materials
ADD FOREIGN KEY (task_id) REFERENCES tasks (id);

ALTER TABLE items
ADD FOREIGN KEY (unit_id) REFERENCES units (id);

ALTER TABLE items
ADD FOREIGN KEY (supplier_id) REFERENCES suppliers (id);

ALTER TABLE tasks
ADD FOREIGN KEY (user_id) REFERENCES users (id);