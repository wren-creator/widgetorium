-- Widgetorium seed database.
-- Loaded once, on first container start, from
-- /docker-entrypoint-initdb.d/10-init.sql (runs as root).
--
-- The MySQL entrypoint has already created database `widgetorium` and user
-- `widgetorium`@`%` with full rights on that schema. This script adds the
-- schema, the seed data, and one deliberate privilege over-grant (FILE) that
-- makes vuln 4's LOAD_FILE() return content instead of NULL.

USE widgetorium;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS stock_ledger;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------------
-- schema
-- ---------------------------------------------------------------------------

CREATE TABLE users (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  username       VARCHAR(64)  NOT NULL UNIQUE,
  email          VARCHAR(190) NOT NULL,
  -- unsalted MD5. Deliberately weak so a hash-cracking sub-exercise works.
  password_hash  CHAR(32)     NOT NULL,
  role           ENUM('customer','admin') NOT NULL DEFAULT 'customer',
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE products (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  -- 255 chars so a full second-order injection payload fits in a product name.
  name           VARCHAR(255)  NOT NULL,
  description     TEXT          NULL,
  price          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  stock          INT           NOT NULL DEFAULT 0,
  -- vuln 4 is supposed to check this against the caller and does not.
  owner_user_id  INT           NULL,
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE orders (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  customer_id    INT           NOT NULL,
  total          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status         ENUM('pending','paid','shipped','cancelled') NOT NULL DEFAULT 'paid',
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- sequential, guessable order numbers for the IDOR walk (vuln 10)
ALTER TABLE orders AUTO_INCREMENT = 1001;

CREATE TABLE order_items (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  order_id       INT           NOT NULL,
  product_id     INT           NOT NULL,
  qty            INT           NOT NULL DEFAULT 1,
  unit_price     DECIMAL(10,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE reviews (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  product_id     INT           NOT NULL,
  author         VARCHAR(120)  NOT NULL,
  -- rendered without output encoding on product.php (vuln 11, stored XSS)
  body           TEXT          NOT NULL,
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sessions (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  -- predictable token: hex(unix_time) . zero-padded hex(user_id) (vuln 13)
  token          VARCHAR(64)   NOT NULL UNIQUE,
  user_id        INT           NOT NULL,
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stock_ledger (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  -- the admin inventory report concatenates a product name into a query
  -- filtered on this column (vuln 3, second-order injection sink)
  label          VARCHAR(255)  NOT NULL,
  delta          INT           NOT NULL DEFAULT 0,
  moved_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- seed: users
--   admin password  = Widgetorium2024!   -> MD5 5f4dcc... (see below, crackable)
--   customer passwords are all weak and in rockyou-class wordlists
-- ---------------------------------------------------------------------------

INSERT INTO users (id, username, email, password_hash, role) VALUES
  (1,  'admin',   'admin@widgetorium.local',  MD5('Widgetorium2024!'), 'admin'),
  (2,  'alice',   'alice@example.test',        MD5('Password123'),      'customer'),
  (3,  'bob',     'bob@example.test',          MD5('letmein'),          'customer'),
  (4,  'carol',   'carol@example.test',        MD5('sunshine'),         'customer'),
  (5,  'dave',    'dave@example.test',         MD5('qwerty'),           'customer'),
  (6,  'erin',    'erin@example.test',         MD5('dragon'),           'customer'),
  (7,  'frank',   'frank@example.test',        MD5('monkey'),           'customer'),
  (8,  'grace',   'grace@example.test',        MD5('iloveyou'),         'customer'),
  (9,  'heidi',   'heidi@example.test',        MD5('trustno1'),         'customer'),
  (10, 'ivan',    'ivan@example.test',         MD5('football'),         'customer'),
  (11, 'judy',    'judy@example.test',         MD5('welcome1'),         'customer'),
  (12, 'mallory', 'mallory@example.test',      MD5('abc123'),           'customer'),
  (13, 'peggy',   'peggy@example.test',        MD5('shadow'),           'customer');

-- ---------------------------------------------------------------------------
-- seed: products (24 aggressively dull widgets)
-- owner_user_id points at a staff-ish account so vuln 4's missing check is visible
-- ---------------------------------------------------------------------------

INSERT INTO products (id, name, description, price, stock, owner_user_id) VALUES
  (1,  'Grey Wall Bracket',            'Powder-coated steel, 120mm.',                   3.49,  420, 1),
  (2,  'Standard M6 Bolt, 50-pack',    'Zinc-plated, DIN 933.',                         4.95,  900, 1),
  (3,  'Beige Cable Tidy, 2m',         'Self-adhesive spiral wrap.',                    2.25,  610, 1),
  (4,  'Rubber Door Stop',             'Wedge, matte black.',                           1.80,  780, 1),
  (5,  'A4 Ring Binder, White',        '2-ring, 40mm spine.',                           2.10,  540, 1),
  (6,  'Desk Grommet, 60mm',           'Two-piece, grey ABS.',                          1.15,  1200, 1),
  (7,  'Furniture Glide Set of 4',     'Felt base, screw-in.',                          3.60,  330, 1),
  (8,  'Cable Gland M20',              'IP68, nylon, black.',                           0.95,  1500, 1),
  (9,  'Blank Keystone Jack',          'Snap-in, unloaded.',                            0.70,  2000, 1),
  (10, 'Velcro Tie Roll, 5m',          'Cut to length, black.',                         5.40,  260, 1),
  (11, 'Shelf Support Pin, 5mm',       'Nickel, pack of 20.',                           1.95,  870, 1),
  (12, 'Hex Key Set, Metric',          '1.5mm to 10mm, folding.',                       6.20,  190, 1),
  (13, 'Self-Tapping Screw, 100-pack', 'Pozidriv, 4x20mm.',                             3.85,  700, 1),
  (14, 'Adjustable Foot, M10',         'Levelling, nylon base.',                        2.75,  410, 1),
  (15, 'Corner Brace, 40mm',           'Zinc-plated, pre-drilled.',                     0.85,  1600, 1),
  (16, 'Trunking, 25x16mm, 2m',        'Self-adhesive, white PVC.',                     4.30,  350, 1),
  (17, 'Blanking Plate, Single Gang',  'White moulded.',                                1.05,  980, 1),
  (18, 'Cable Clip, 7mm, 100-pack',    'Round, with masonry nail.',                     2.40,  760, 1),
  (19, 'P-Clip, 20mm, 10-pack',        'Rubber-lined, zinc.',                           1.70,  640, 1),
  (20, 'Grommet Strip, 3m',            'Edge trim, black.',                             3.10,  300, 1),
  (21, 'Threaded Insert, M4, 20-pack', 'Brass, knurled.',                              2.55,  520, 1),
  (22, 'Draught Excluder, 1m',         'Self-adhesive foam, brown.',                    1.60,  580, 1),
  (23, 'Cabinet Handle, 96mm',         'Brushed nickel, bar.',                          2.90,  470, 1),
  (24, 'Rubber Feet, 20mm, Set of 8',  'Self-adhesive, black.',                         1.35,  1100, 1);

-- ---------------------------------------------------------------------------
-- seed: stock_ledger
--   label matches real product names so the admin inventory report returns
--   non-empty rows even before any injection payload is planted
-- ---------------------------------------------------------------------------

INSERT INTO stock_ledger (label, delta) VALUES
  ('Grey Wall Bracket',         500),  ('Grey Wall Bracket',        -80),
  ('Standard M6 Bolt, 50-pack', 1000), ('Standard M6 Bolt, 50-pack', -100),
  ('Beige Cable Tidy, 2m',      700),  ('Beige Cable Tidy, 2m',      -90),
  ('Rubber Door Stop',          820),  ('Rubber Door Stop',          -40),
  ('A4 Ring Binder, White',     600),  ('A4 Ring Binder, White',     -60),
  ('Desk Grommet, 60mm',        1300), ('Desk Grommet, 60mm',        -100),
  ('Cable Gland M20',           1600), ('Cable Gland M20',           -100),
  ('Hex Key Set, Metric',       220),  ('Hex Key Set, Metric',       -30),
  ('Cabinet Handle, 96mm',      520),  ('Cabinet Handle, 96mm',      -50);

-- ---------------------------------------------------------------------------
-- seed: orders 1001-1030 across multiple customers, for the IDOR walk
-- ---------------------------------------------------------------------------

INSERT INTO orders (id, customer_id, total, status, created_at) VALUES
  (1001, 2,  12.43, 'paid',      '2026-07-02 09:14:00'),
  (1002, 3,   4.95, 'shipped',   '2026-07-02 11:40:00'),
  (1003, 2,  27.80, 'paid',      '2026-07-03 08:05:00'),
  (1004, 4,   9.10, 'paid',      '2026-07-03 16:22:00'),
  (1005, 5,  15.55, 'cancelled', '2026-07-04 10:01:00'),
  (1006, 6,   6.20, 'shipped',   '2026-07-05 12:33:00'),
  (1007, 3,  33.40, 'paid',      '2026-07-06 09:47:00'),
  (1008, 7,   2.25, 'paid',      '2026-07-06 14:12:00'),
  (1009, 8,  48.90, 'shipped',   '2026-07-07 10:29:00'),
  (1010, 2,   7.05, 'paid',      '2026-07-08 08:55:00'),
  (1011, 9,  19.20, 'paid',      '2026-07-09 13:41:00'),
  (1012, 10, 11.30, 'shipped',   '2026-07-10 09:03:00'),
  (1013, 4,   3.60, 'paid',      '2026-07-10 17:18:00'),
  (1014, 11, 22.75, 'paid',      '2026-07-11 11:52:00'),
  (1015, 5,   5.40, 'cancelled', '2026-07-12 10:44:00'),
  (1016, 12, 40.10, 'shipped',   '2026-07-13 09:16:00'),
  (1017, 6,   8.85, 'paid',      '2026-07-14 15:39:00'),
  (1018, 3,  14.60, 'paid',      '2026-07-15 08:22:00'),
  (1019, 13, 51.25, 'shipped',   '2026-07-16 12:07:00'),
  (1020, 7,   1.80, 'paid',      '2026-07-17 10:58:00'),
  (1021, 8,  17.95, 'paid',      '2026-07-18 14:33:00'),
  (1022, 2,  25.00, 'shipped',   '2026-07-19 09:41:00'),
  (1023, 9,   6.90, 'paid',      '2026-07-20 11:19:00'),
  (1024, 10, 12.40, 'paid',      '2026-07-21 16:04:00'),
  (1025, 4,  38.70, 'shipped',   '2026-07-22 08:47:00'),
  (1026, 11,  4.30, 'paid',      '2026-07-23 13:52:00'),
  (1027, 5,  20.15, 'paid',      '2026-07-24 10:26:00'),
  (1028, 12,  9.55, 'cancelled', '2026-07-25 12:38:00'),
  (1029, 6,  31.00, 'shipped',   '2026-07-26 09:12:00'),
  (1030, 3,   7.70, 'paid',      '2026-07-27 15:47:00');

INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES
  (1001, 1, 2, 3.49), (1001, 6, 1, 1.15), (1001, 3, 1, 2.25), (1001, 8, 4, 0.95),
  (1002, 2, 1, 4.95),
  (1003, 12, 2, 6.20), (1003, 10, 1, 5.40), (1003, 23, 3, 2.90),
  (1004, 7, 1, 3.60), (1004, 15, 2, 0.85), (1004, 4, 2, 1.80),
  (1005, 16, 1, 4.30), (1005, 20, 1, 3.10), (1005, 12, 1, 6.20),
  (1006, 12, 1, 6.20),
  (1007, 9, 10, 0.70), (1007, 13, 5, 3.85), (1007, 8, 7, 0.95),
  (1008, 3, 1, 2.25),
  (1009, 19, 3, 1.70), (1009, 12, 2, 6.20), (1009, 10, 5, 5.40),
  (1010, 24, 1, 1.35), (1010, 17, 2, 1.05), (1010, 6, 3, 1.15),
  (1011, 5, 4, 2.10), (1011, 11, 2, 1.95), (1011, 21, 2, 2.55),
  (1012, 18, 2, 2.40), (1012, 22, 4, 1.60),
  (1013, 7, 1, 3.60),
  (1014, 12, 2, 6.20), (1014, 16, 1, 4.30), (1014, 23, 2, 2.90),
  (1015, 10, 1, 5.40),
  (1016, 9, 20, 0.70), (1016, 8, 15, 0.95), (1016, 13, 3, 3.85),
  (1017, 14, 2, 2.75), (1017, 19, 2, 1.70),
  (1018, 3, 3, 2.25), (1018, 6, 4, 1.15), (1018, 24, 2, 1.35),
  (1019, 12, 4, 6.20), (1019, 10, 3, 5.40), (1019, 23, 3, 2.90),
  (1020, 4, 1, 1.80),
  (1021, 16, 2, 4.30), (1021, 20, 1, 3.10), (1021, 7, 1, 3.60),
  (1022, 13, 5, 3.85), (1022, 2, 1, 4.95),
  (1023, 8, 3, 0.95), (1023, 15, 4, 0.85),
  (1024, 11, 2, 1.95), (1024, 21, 3, 2.55), (1024, 24, 1, 1.35),
  (1025, 12, 3, 6.20), (1025, 10, 2, 5.40), (1025, 16, 2, 4.30),
  (1026, 16, 1, 4.30),
  (1027, 5, 3, 2.10), (1027, 12, 1, 6.20), (1027, 23, 2, 2.90),
  (1028, 22, 4, 1.60), (1028, 17, 2, 1.05),
  (1029, 9, 12, 0.70), (1029, 13, 4, 3.85), (1029, 8, 8, 0.95),
  (1030, 3, 2, 2.25), (1030, 6, 2, 1.15);

-- ---------------------------------------------------------------------------
-- seed: a few benign reviews (the stored-XSS sink starts clean)
-- ---------------------------------------------------------------------------

INSERT INTO reviews (product_id, author, body, created_at) VALUES
  (1,  'alice', 'Held the shelf fine. No complaints.',                 '2026-07-05 10:00:00'),
  (2,  'bob',   'Bolts are bolts. Fit the holes.',                     '2026-07-06 14:20:00'),
  (12, 'carol', 'Handy little set, the 6mm gets the most use.',        '2026-07-08 09:30:00'),
  (12, 'dave',  'Folding hinge feels cheap but works.',                '2026-07-09 16:45:00'),
  (23, 'erin',  'Nicer finish than the photo. Screws included.',       '2026-07-11 11:05:00'),
  (10, 'frank', 'Cut a bit short but does the job.',                   '2026-07-13 13:15:00');

-- ---------------------------------------------------------------------------
-- deliberate privilege over-grant for vuln 4 (file read via LOAD_FILE)
-- ---------------------------------------------------------------------------

GRANT FILE ON *.* TO 'widgetorium'@'%';
FLUSH PRIVILEGES;
