-- SELECT all tasks with or without user_id parameter:
SELECT
  u.username, 
  tt.name || ' of planting n.' || t.planting_id || ', variety: ' || c.variety AS Task,
  'Status: ' || ts.name AS Status, 
  'Due: ' || TO_CHAR(t.due, 'DD.MM.YYYY') AS Due 
FROM
  tasks AS t
JOIN
  task_types AS tt ON t.type_id = tt.id
JOIN
  task_status AS ts ON t.status_id = ts.id
JOIN
  plantings AS p ON t.planting_id = p.id
JOIN
  crops AS c ON p.crop_id = c.id
LEFT JOIN
  users AS u ON t.user_id = u.id
-- Filter to select a specific one:
WHERE
  (t.user_id = COALESCE($1, t.user_id) OR ($1 IS NULL AND t.user_id IS NULL)) AND
  t.due <= CURRENT_DATE + INTERVAL '2 day'
  AND t.status_id <> 5 -- Without done - Optional
--   AND t.status_id <> 2 -- Without assigned - Optional
--   AND t.status_id <> 3 -- Without In progress - Optional
--   AND t.status_id = 4 -- Overdue - Optional
ORDER BY t.due
-- -- ** -- --


-- SELECT all plantings:
SELECT
  c.variety,
  p.planting_date,
  p.harvesting_date,
  p.size,
  p.is_trial,
  p.id AS bed_number
FROM
  plantings AS p
JOIN
  crops AS c ON p.crop_id = c.id
-- Filter to select a specific one:
WHERE
  p.id = COALESCE($1, p.id) OR
  ($1 IS NULL AND p.id IS NULL)
-- -- ** -- --


-- SELECT beds list with available space:
WITH used_space AS(
  SELECT
    SUM(p.size) AS used_space_per_bed,
    p.bed_id
  FROM
    plantings AS p
  GROUP BY
    p.bed_id
)
SELECT
  b.id AS bed_number,
  us.used_space_per_bed AS used_space,
  b.size AS total_size
FROM
  beds AS b
JOIN
  used_space AS us ON b.id = us.bed_id
-- -- ** -- --


-- SELECT stock quantities
WITH stock_qty AS(
  SELECT
    s.item_id,
    SUM(s.stock_movement) AS qty
  FROM
    stocks AS s
  GROUP BY
    s.item_id
)
SELECT
  i.name,
  sq.qty,
  u.unit
FROM
  items AS i
JOIN
  units AS u ON i.unit_id = u.id
JOIN
  stock_qty AS sq ON i.id = sq.item_id
-- -- ** -- --


-- SELECT find stock depletion rate and date where qty will get to zero
WITH stock_qty AS(
    SELECT
      s.item_id,
      SUM(s.stock_movement) AS qty
    FROM
      stocks AS s
    GROUP BY
      s.item_id
),
item_qty AS(
  SELECT
    i.name,
    sq.qty,
    u.unit
  FROM
    items AS i
  JOIN
    units AS u ON i.unit_id = u.id
  JOIN
    stock_qty AS sq ON i.id = sq.item_id
  WHERE
    sq.item_id = $1
),
last_resupply AS(
  SELECT
    s.datetime
  FROM
    stocks AS s
  WHERE
  -- REPLACE 6 BY VARIABLE $1
    s.item_id = 6 AND
    s.stock_movement > 0
  ORDER BY
    s.datetime DESC
  LIMIT
    1
)
SELECT
  (SELECT lr.datetime FROM last_resupply AS lr) AS last_resupply,
  ROUND(SUM(s.stock_movement)) AS out_since_last_resupply,
  EXTRACT(day FROM (LOCALTIMESTAMP - (SELECT datetime FROM last_resupply))) AS days_since_last_resupply,
  ROUND(
    (
      -SUM(s.stock_movement)
      /
      NULLIF(
        EXTRACT(
          day FROM (LOCALTIMESTAMP - (SELECT datetime FROM last_resupply))
        ),
        0
      )
    )::numeric
  ) AS items_per_day,
  (SELECT q.qty FROM item_qty AS q) AS qty,
  ROUND(
    -(SELECT q.qty FROM item_qty AS q)
    /
    NULLIF(
      ROUND(
        (
          SUM(s.stock_movement)
          /
          NULLIF(
            EXTRACT(
              day FROM (LOCALTIMESTAMP - (SELECT datetime FROM last_resupply))
            ),
            0
          )
        )::numeric
      ),
      0
    )
  ) AS days_to_zero,
  CURRENT_DATE + ROUND(
    -(SELECT q.qty FROM item_qty AS q)
    /
    NULLIF(
      ROUND(
        (
          SUM(s.stock_movement)
          /
          NULLIF(
            EXTRACT(
              day FROM (LOCALTIMESTAMP - (SELECT datetime FROM last_resupply))
            ),
            0
          )
        )::numeric
      ),
      0
    )
  )::integer AS zero_date
FROM
  stocks AS s
WHERE
  s.item_id = $1 AND
  s.stock_movement < 0 AND
  s.datetime > (SELECT lr.datetime FROM last_resupply AS lr)
-- -- ** -- --


-- SELECT task supplies
SELECT
  t.id,
  i.name,
  tm.qty,
  u.unit
FROM
  items AS i
JOIN
  task_materials AS tm ON tm.item_id = i.id
JOIN
  units AS u ON i.unit_id = u.id
JOIN
  tasks AS t ON tm.task_id = t.id
-- Filter by task:
WHERE
  t.id = COALESCE($1, t.id) OR
  ($1 IS NULL AND t.id IS NULL)
-- -- ** -- --


-- SELECT notes
SELECT
  p.id AS planting_number,
  p.bed_id AS bed_number,
  c.variety,
  n.text AS note,
  n.datetime
FROM
  notes AS n
JOIN
  plantings AS p ON n.planting_id = p.id
JOIN
  crops AS c ON p.crop_id = c.id
-- Filter by planting:
WHERE
  p.id = COALESCE($1, p.id) OR
  ($1 IS NULL AND p.id IS NULL)
-- -- ** -- --


-- SELECT units
SELECT
  id,
  unit
FROM
  units
-- -- ** -- --


-- SELECT suppliers
SELECT
  id,
  name
FROM
  suppliers
-- -- ** -- --


-- UPDATE task due date every day when due date is in the past
-- (execute after 01:00 in the morning, server local time is UTC)
UPDATE tasks
SET
  due = GREATEST(due, CURRENT_DATE + 1)
WHERE
  due <= CURRENT_DATE
-- -- ** -- --



-- UPDATE archive user
UPDATE users
SET
  active = false
WHERE
  id = $1
-- -- ** -- --


-- UPDATE task at assignment by a user
UPDATE tasks
SET
  user_id = $2,
  due = GREATEST(due, CURRENT_DATE + 1),
  status_id = 2
WHERE
  id = $1
-- -- ** -- --


-- UPDATE task at start
UPDATE tasks
SET
  start_time = LOCALTIMESTAMP,
  due = GREATEST(due, CURRENT_DATE + 1),
  status_id = 3
WHERE
  id = $1
-- -- ** -- --


-- UPDATE task when completed AND UPDATE stock quantities
WITH update_task AS(
  UPDATE tasks
  SET
    end_time = LOCALTIMESTAMP,
    due = GREATEST(due, CURRENT_DATE + 1),
    status_id = 5
  WHERE
    id = $1
  RETURNING id
)
-- Then INSERT new stock line
INSERT INTO stocks(
  item_id,
  stock_movement
)
SELECT
  i.id,
  -tm.qty
FROM
  items AS i
JOIN
  task_materials AS tm ON tm.item_id = i.id
JOIN
  update_task AS ut ON tm.task_id = ut.id
-- -- ** -- --


-- UPDATE stock quantities upon order reception
INSERT INTO stocks(
  item_id,
  stock_movement
)
VALUES(
  $1,
  $2
)
-- -- ** -- --


-- INSERT new plantings (add all tasks related to the crop after insertion in progress)
INSERT INTO plantings(
  bed_id,
  crop_id,
  harvesting_date,
  is_trial,
  size
  )
SELECT
  $1,
  $2,
  CURRENT_DATE + c.harvesting_window,
  $3,
  $4
FROM
  crops AS c
WHERE
  c.id = $2 AND
  $4 <= (
    SELECT
      b.size - COALESCE(SUM(p.size), 0)
    FROM
      beds b
    LEFT JOIN
      plantings p ON p.bed_id = b.id
    WHERE
      b.id = $1
    GROUP BY
      b.size
  )
RETURNING id
-- RETURNING statement is to be used to check if the insertion was successful:
-- (id != null => enough space, id == null => not enough space in selected  bed)
-- app must listen to that and react accordingly

-- Then add related tasks based on crop intervals (in progress)
-- Add watering tasks(type_id=1)
do $$
begin
  for counter in 1..(SELECT harvesting_window FROM crops WHERE id = 4) by (SELECT watering_interval FROM crops WHERE id = 4) loop
    raise notice 'Watering date: %', CURRENT_DATE + counter;
	INSERT INTO tasks (type_id, user_id, planting_id, due)
	VALUES
	(1, NULL, 1, CURRENT_DATE + counter);
  end loop;
end; $$

-- Add thin tasks(type_id=2)
do $$
begin
  for counter in 1..(SELECT harvesting_window FROM crops WHERE id = 4) by (SELECT thin_interval FROM crops WHERE id = 4) loop
    raise notice 'Watering date: %', CURRENT_DATE + counter;
	INSERT INTO tasks (type_id, user_id, planting_id, due)
	VALUES
	(2, NULL, 1, CURRENT_DATE + counter);
  end loop;
end; $$

-- Add scout pest tasks(type_id=3)
do $$
begin
  for counter in 1..(SELECT harvesting_window FROM crops WHERE id = 4) by (SELECT scout_pest_interval FROM crops WHERE id = 4) loop
    raise notice 'Watering date: %', CURRENT_DATE + counter;
	INSERT INTO tasks (type_id, user_id, planting_id, due)
	VALUES
	(3, NULL, 1, CURRENT_DATE + counter);
  end loop;
end; $$
-- -- ** -- --


-- INSERT new user
INSERT INTO users(
  pwd,
  username,
  first_name,
  last_name
)
VALUES(
  $1,
  $2,
  $3,
  $4
)
-- -- ** -- --


-- INSERT new crop variety
WITH new_items AS(
  INSERT INTO items(
    name,
    supplier_id,
    unit_id
  )
  VALUES(
    $1,
    $6,
    $7
  )
  RETURNING id
)
INSERT INTO crops(
  item_id,
  variety,
  watering_interval,
  harvesting_window,
  thin_interval,
  scout_pest_interval
)
SELECT
  id,
  $1,
  $2, 
  $3,
  $4,
  $5
FROM 
  new_items
-- -- ** -- --