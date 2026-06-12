-- =============================================================================
-- Seed Data — Corporate Catering Operations Analysis
-- Purpose:  Populate all tables with realistic synthetic data covering
--           24 months of operations (2023-01 through 2024-12).
--           Volume: 20 accounts · 15 caterers · ~600 orders · ~1,800 items
-- Note:     All company names and figures are fictitious.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- corporate_accounts  (20 rows — mix of SMB / mid-market / enterprise)
-- -----------------------------------------------------------------------------
INSERT INTO corporate_accounts (company_name, industry, account_tier, city, state_code, created_at) VALUES
('Axiom Technology Partners',   'Technology',       'enterprise',   'Boston',       'MA', '2023-01-05'),
('BlueSky Ventures LLC',        'Finance',          'mid_market',   'Boston',       'MA', '2023-01-18'),
('Cornerstone Legal Group',     'Legal',            'mid_market',   'Boston',       'MA', '2023-02-03'),
('DataStream Analytics',        'Technology',       'smb',          'Cambridge',    'MA', '2023-02-14'),
('EverGreen Pharma',            'Healthcare',       'enterprise',   'Worcester',    'MA', '2023-03-01'),
('Franklin & Moore CPAs',       'Finance',          'smb',          'Boston',       'MA', '2023-03-22'),
('GreenPath Consulting',        'Consulting',       'smb',          'Newton',       'MA', '2023-04-08'),
('Harborview Media',            'Media',            'mid_market',   'Boston',       'MA', '2023-04-15'),
('IronBridge Construction',     'Construction',     'smb',          'Quincy',       'MA', '2023-05-02'),
('JetStream Logistics',         'Logistics',        'mid_market',   'Worcester',    'MA', '2023-05-19'),
('Kinetic Health Systems',      'Healthcare',       'enterprise',   'Boston',       'MA', '2023-06-01'),
('Lighthouse Education',        'Education',        'smb',          'Cambridge',    'MA', '2023-06-20'),
('Meridian Software',           'Technology',       'mid_market',   'Boston',       'MA', '2023-07-07'),
('NorthPoint Capital',          'Finance',          'enterprise',   'Boston',       'MA', '2023-07-25'),
('Orion Engineering',           'Engineering',      'mid_market',   'Waltham',      'MA', '2023-08-10'),
('Pinnacle Realty Group',       'Real Estate',      'smb',          'Newton',       'MA', '2023-08-28'),
('Quantum Dynamics',            'Technology',       'mid_market',   'Cambridge',    'MA', '2023-09-12'),
('RedRock Insurance',           'Insurance',        'smb',          'Boston',       'MA', '2023-09-30'),
('Silverline Biotech',          'Healthcare',       'enterprise',   'Worcester',    'MA', '2023-10-15'),
('TrueNorth Advisory',          'Consulting',       'smb',          'Boston',       'MA', '2023-11-01');


-- -----------------------------------------------------------------------------
-- caterers  (15 rows — diverse cuisine types, realistic rating spread)
-- -----------------------------------------------------------------------------
INSERT INTO caterers (caterer_name, city, state_code, cuisine_type, avg_rating, total_reviews, onboarded_at) VALUES
('Boston Box Lunch Co.',        'Boston',       'MA', 'American',         4.7,  312, '2022-06-01'),
('Spice Route Catering',        'Cambridge',    'MA', 'Indian',           4.5,  198, '2022-08-15'),
('Harbor Fresh Kitchen',        'Boston',       'MA', 'American',         4.3,  254, '2022-09-01'),
('Bella Cucina Events',         'Newton',       'MA', 'Italian',          4.8,  421, '2022-07-20'),
('Green Garden Catering',       'Cambridge',    'MA', 'Vegetarian',       4.6,  187, '2022-11-10'),
('Taqueria Del Sol',            'Boston',       'MA', 'Mexican',          4.4,  276, '2023-01-05'),
('The Grain Bowl',              'Waltham',      'MA', 'American',         4.2,  143, '2023-02-18'),
('Mediterranean Table',         'Boston',       'MA', 'Mediterranean',    4.7,  309, '2022-10-01'),
('Seoul Kitchen Catering',      'Cambridge',    'MA', 'Korean',           4.5,  165, '2023-03-12'),
('New England Deli',            'Quincy',       'MA', 'American',         3.9,   98, '2023-04-01'),
('Saffron House',               'Boston',       'MA', 'Middle Eastern',   4.6,  234, '2022-12-05'),
('Pacific Rim Catering',        'Boston',       'MA', 'Asian Fusion',     4.3,  201, '2023-05-20'),
('The Smokehouse BBQ',          'Worcester',    'MA', 'BBQ',              4.1,  178, '2023-03-08'),
('Garden State Greens',         'Newton',       'MA', 'Vegetarian',       4.4,  132, '2023-06-15'),
('Federal Street Fare',         'Boston',       'MA', 'American',         3.8,   87, '2023-07-01');


-- -----------------------------------------------------------------------------
-- promotions
-- -----------------------------------------------------------------------------
INSERT INTO promotions (promo_code, description, discount_type, discount_value, start_date, end_date, target_tier) VALUES
('WELCOME25',   'New account flat discount',            'flat',             25.00,  '2023-01-01', '2023-06-30', 'smb'),
('ENT100',      'Enterprise Q1 credit',                 'flat',            100.00,  '2023-01-01', '2023-03-31', 'enterprise'),
('FREESHIP',    'Free delivery for mid-market Q2',      'free_delivery',     0.00,  '2023-04-01', '2023-06-30', 'mid_market'),
('SUMMER15',    '15% off summer orders',                'percent',          15.00,  '2023-07-01', '2023-08-31', NULL),
('Q4BOOST',     '$50 off Q4 enterprise orders',         'flat',             50.00,  '2023-10-01', '2023-12-31', 'enterprise'),
('NY2024',      'New Year free delivery all tiers',     'free_delivery',     0.00,  '2024-01-01', '2024-01-31', NULL),
('SPRING20',    '20% off spring — mid-market',          'percent',          20.00,  '2024-03-01', '2024-05-31', 'mid_market'),
('LOYAL50',     '$50 loyalty credit — 10+ orders',      'flat',             50.00,  '2024-06-01', '2024-12-31', NULL);


-- -----------------------------------------------------------------------------
-- orders  (~120 rows — 24 months, distributed across accounts & caterers)
-- For brevity the seed uses a VALUES block; in production this would be
-- generated via a pipeline or dbt seed file.
-- -----------------------------------------------------------------------------
INSERT INTO orders (account_id, caterer_id, order_status, delivery_tier, headcount, order_total_usd, delivery_fee_usd, discount_usd, placed_at, scheduled_delivery, actual_delivery) VALUES
-- 2023 Q1
(1,  1, 'delivered', 'standard',   45, 675.00,  15.00,   0.00, '2023-01-10 09:00+00', '2023-01-10 11:30+00', '2023-01-10 11:25+00'),
(1,  4, 'delivered', 'express',    60, 960.00,  25.00, 100.00, '2023-01-24 10:00+00', '2023-01-24 12:00+00', '2023-01-24 12:10+00'),
(2,  6, 'delivered', 'standard',   20, 280.00,  10.00,   0.00, '2023-02-07 08:30+00', '2023-02-07 11:00+00', '2023-02-07 11:05+00'),
(3,  8, 'delivered', 'scheduled',  35, 525.00,  12.00,   0.00, '2023-02-14 09:00+00', '2023-02-14 12:00+00', '2023-02-14 12:00+00'),
(5,  4, 'delivered', 'express',    80,1280.00,  30.00, 100.00, '2023-02-28 10:00+00', '2023-02-28 12:30+00', '2023-02-28 12:45+00'),
(4,  5, 'delivered', 'standard',   15, 195.00,  10.00,  25.00, '2023-03-06 09:00+00', '2023-03-06 11:30+00', '2023-03-06 11:20+00'),
(6,  3, 'delivered', 'standard',   12, 168.00,  10.00,  25.00, '2023-03-15 08:00+00', '2023-03-15 10:30+00', '2023-03-15 10:35+00'),
(11, 1, 'delivered', 'express',   100,1550.00,  35.00, 100.00, '2023-03-22 09:30+00', '2023-03-22 12:00+00', '2023-03-22 11:55+00'),
-- 2023 Q2
(1,  8, 'delivered', 'scheduled',  50, 850.00,   0.00,   0.00, '2023-04-05 09:00+00', '2023-04-05 12:00+00', '2023-04-05 12:05+00'),
(2,  6, 'delivered', 'standard',   25, 350.00,   0.00,   0.00, '2023-04-18 08:30+00', '2023-04-18 11:00+00', '2023-04-18 11:00+00'),
(7,  5, 'delivered', 'standard',   10, 130.00,  10.00,  25.00, '2023-04-25 09:00+00', '2023-04-25 11:30+00', '2023-04-25 11:45+00'),
(8,  8, 'delivered', 'standard',   30, 480.00,   0.00,   0.00, '2023-05-03 10:00+00', '2023-05-03 12:30+00', '2023-05-03 12:25+00'),
(5,  1, 'delivered', 'express',    90,1395.00,  35.00,   0.00, '2023-05-16 09:00+00', '2023-05-16 11:30+00', '2023-05-16 11:40+00'),
(10, 13,'delivered', 'standard',   40, 520.00,  12.00,   0.00, '2023-05-24 09:30+00', '2023-05-24 12:00+00', '2023-05-24 12:30+00'),
(3,  4, 'delivered', 'scheduled',  45, 720.00,  12.00,   0.00, '2023-06-06 08:00+00', '2023-06-06 12:00+00', '2023-06-06 11:50+00'),
(11, 8, 'delivered', 'express',   120,2040.00,  40.00,   0.00, '2023-06-20 10:00+00', '2023-06-20 12:30+00', '2023-06-20 12:30+00'),
(14, 1, 'delivered', 'standard',   55, 825.00,  15.00,   0.00, '2023-06-28 09:00+00', '2023-06-28 12:00+00', '2023-06-28 12:10+00'),
-- 2023 Q3
(1,  4, 'delivered', 'scheduled',  65,1105.00,  20.00, 165.75, '2023-07-11 09:00+00', '2023-07-11 12:00+00', '2023-07-11 12:00+00'),
(2,  9, 'delivered', 'standard',   22, 330.00,  10.00,  49.50, '2023-07-19 08:30+00', '2023-07-19 11:00+00', '2023-07-19 11:20+00'),
(5, 11, 'delivered', 'express',    75,1200.00,  30.00, 180.00, '2023-07-27 10:00+00', '2023-07-27 12:00+00', '2023-07-27 12:15+00'),
(13, 2, 'delivered', 'standard',   28, 420.00,  12.00,  63.00, '2023-08-08 09:00+00', '2023-08-08 11:30+00', '2023-08-08 11:30+00'),
(4,  5, 'delivered', 'standard',   18, 234.00,  10.00,  35.10, '2023-08-15 08:00+00', '2023-08-15 11:00+00', '2023-08-15 10:55+00'),
(8, 12, 'delivered', 'standard',   35, 560.00,  12.00,  84.00, '2023-08-23 09:30+00', '2023-08-23 12:00+00', '2023-08-23 12:20+00'),
(11, 4, 'delivered', 'express',   110,1870.00,  40.00, 280.50, '2023-09-06 10:00+00', '2023-09-06 12:00+00', '2023-09-06 12:05+00'),
(15, 7, 'delivered', 'standard',   30, 390.00,  12.00,  58.50, '2023-09-13 08:30+00', '2023-09-13 11:30+00', '2023-09-13 11:45+00'),
(3,  8, 'delivered', 'scheduled',  40, 680.00,  15.00, 102.00, '2023-09-21 09:00+00', '2023-09-21 12:00+00', '2023-09-21 12:00+00'),
-- 2023 Q4
(1,  1, 'delivered', 'standard',   50, 750.00,  15.00,  50.00, '2023-10-04 09:00+00', '2023-10-04 12:00+00', '2023-10-04 11:50+00'),
(5,  4, 'delivered', 'express',    95,1615.00,  35.00,  50.00, '2023-10-17 10:00+00', '2023-10-17 12:00+00', '2023-10-17 12:20+00'),
(14, 8, 'delivered', 'scheduled',  60,1020.00,  20.00,  50.00, '2023-10-25 09:00+00', '2023-10-25 12:00+00', '2023-10-25 12:10+00'),
(11, 1, 'delivered', 'express',   130,2015.00,  45.00,  50.00, '2023-11-08 10:00+00', '2023-11-08 12:30+00', '2023-11-08 12:25+00'),
(2,  6, 'delivered', 'standard',   20, 280.00,  10.00,   0.00, '2023-11-15 08:30+00', '2023-11-15 11:00+00', '2023-11-15 11:10+00'),
(7,  5, 'delivered', 'standard',   14, 182.00,  10.00,  25.00, '2023-11-22 09:00+00', '2023-11-22 11:30+00', '2023-11-22 11:30+00'),
(19, 4, 'delivered', 'express',    85,1445.00,  30.00,  50.00, '2023-12-05 10:00+00', '2023-12-05 12:00+00', '2023-12-05 12:05+00'),
(1,  8, 'delivered', 'scheduled',  55, 935.00,  15.00,  50.00, '2023-12-12 09:00+00', '2023-12-12 12:00+00', '2023-12-12 12:00+00'),
(5,  1, 'delivered', 'express',   105,1627.50,  40.00,  50.00, '2023-12-19 09:30+00', '2023-12-19 12:00+00', '2023-12-19 12:10+00'),
-- 2024 Q1
(1,  4, 'delivered', 'scheduled',  70,1190.00,   0.00,   0.00, '2024-01-09 09:00+00', '2024-01-09 12:00+00', '2024-01-09 12:00+00'),
(2,  6, 'delivered', 'standard',   22, 308.00,   0.00,   0.00, '2024-01-16 08:30+00', '2024-01-16 11:00+00', '2024-01-16 11:05+00'),
(11, 8, 'delivered', 'express',   115,1955.00,   0.00,   0.00, '2024-01-23 10:00+00', '2024-01-23 12:30+00', '2024-01-23 12:40+00'),
(5,  4, 'delivered', 'express',    90,1530.00,  35.00,   0.00, '2024-02-06 10:00+00', '2024-02-06 12:00+00', '2024-02-06 12:10+00'),
(13, 2, 'delivered', 'standard',   30, 450.00,  12.00,   0.00, '2024-02-14 09:00+00', '2024-02-14 11:30+00', '2024-02-14 11:25+00'),
(3,  8, 'delivered', 'scheduled',  42, 714.00,  15.00,   0.00, '2024-02-21 09:00+00', '2024-02-21 12:00+00', '2024-02-21 11:55+00'),
(14, 1, 'delivered', 'standard',   58, 870.00,  15.00,   0.00, '2024-03-05 09:00+00', '2024-03-05 12:00+00', '2024-03-05 12:15+00'),
(8, 12, 'delivered', 'standard',   38, 608.00,  12.00,   0.00, '2024-03-12 09:30+00', '2024-03-12 12:00+00', '2024-03-12 12:05+00'),
(1,  4, 'delivered', 'express',    72,1224.00,  25.00,   0.00, '2024-03-20 10:00+00', '2024-03-20 12:00+00', '2024-03-20 11:50+00'),
-- 2024 Q2
(11, 1, 'delivered', 'express',   125,1937.50,  45.00,   0.00, '2024-04-02 10:00+00', '2024-04-02 12:30+00', '2024-04-02 12:25+00'),
(5,  8, 'delivered', 'scheduled',  85,1445.00,   0.00, 289.00, '2024-04-10 09:00+00', '2024-04-10 12:00+00', '2024-04-10 12:00+00'),
(2,  9, 'delivered', 'standard',   25, 375.00,   0.00,  75.00, '2024-04-18 08:30+00', '2024-04-18 11:00+00', '2024-04-18 11:10+00'),
(7,  5, 'delivered', 'standard',   16, 208.00,   0.00,  41.60, '2024-04-25 09:00+00', '2024-04-25 11:30+00', '2024-04-25 11:30+00'),
(15, 7, 'delivered', 'standard',   32, 416.00,  12.00,  83.20, '2024-05-07 08:30+00', '2024-05-07 11:30+00', '2024-05-07 11:50+00'),
(1,  8, 'delivered', 'scheduled',  60,1020.00,  20.00, 204.00, '2024-05-14 09:00+00', '2024-05-14 12:00+00', '2024-05-14 12:05+00'),
(19, 4, 'delivered', 'express',    80,1360.00,  30.00, 272.00, '2024-05-22 10:00+00', '2024-05-22 12:00+00', '2024-05-22 12:20+00'),
(3,  4, 'delivered', 'scheduled',  48, 816.00,  15.00, 163.20, '2024-06-04 09:00+00', '2024-06-04 12:00+00', '2024-06-04 11:55+00'),
(14, 8, 'delivered', 'scheduled',  65,1105.00,  20.00, 221.00, '2024-06-11 09:00+00', '2024-06-11 12:00+00', '2024-06-11 12:10+00'),
(4,  5, 'delivered', 'standard',   20, 260.00,  10.00,  52.00, '2024-06-19 08:00+00', '2024-06-19 11:30+00', '2024-06-19 11:25+00'),
-- 2024 Q3
(1,  4, 'delivered', 'express',    75,1275.00,  25.00,  50.00, '2024-07-09 10:00+00', '2024-07-09 12:00+00', '2024-07-09 12:05+00'),
(5,  1, 'delivered', 'express',   100,1550.00,  35.00,  50.00, '2024-07-16 09:30+00', '2024-07-16 12:00+00', '2024-07-16 12:10+00'),
(11, 4, 'delivered', 'express',   120,2040.00,  45.00,  50.00, '2024-07-23 10:00+00', '2024-07-23 12:30+00', '2024-07-23 12:25+00'),
(2,  6, 'delivered', 'standard',   24, 336.00,  10.00,  50.00, '2024-08-06 08:30+00', '2024-08-06 11:00+00', '2024-08-06 11:00+00'),
(8, 12, 'delivered', 'standard',   40, 640.00,  12.00,  50.00, '2024-08-13 09:30+00', '2024-08-13 12:00+00', '2024-08-13 12:30+00'),
(13, 2, 'delivered', 'standard',   32, 480.00,  12.00,  50.00, '2024-08-21 09:00+00', '2024-08-21 11:30+00', '2024-08-21 11:25+00'),
(3,  8, 'delivered', 'scheduled',  44, 748.00,  15.00,  50.00, '2024-09-04 09:00+00', '2024-09-04 12:00+00', '2024-09-04 12:00+00'),
(14, 1, 'delivered', 'standard',   60, 900.00,  15.00,  50.00, '2024-09-11 09:00+00', '2024-09-11 12:00+00', '2024-09-11 12:20+00'),
(19, 8, 'delivered', 'express',    90,1530.00,  35.00,  50.00, '2024-09-18 10:00+00', '2024-09-18 12:00+00', '2024-09-18 12:15+00'),
-- 2024 Q4
(1,  4, 'delivered', 'express',    80,1360.00,  30.00,   0.00, '2024-10-02 10:00+00', '2024-10-02 12:00+00', '2024-10-02 12:05+00'),
(5,  4, 'delivered', 'express',   105,1785.00,  40.00,   0.00, '2024-10-09 10:00+00', '2024-10-09 12:00+00', '2024-10-09 12:15+00'),
(11, 1, 'delivered', 'express',   135,2092.50,  45.00,   0.00, '2024-10-16 10:00+00', '2024-10-16 12:30+00', '2024-10-16 12:30+00'),
(14, 8, 'delivered', 'scheduled',  68,1156.00,  20.00,   0.00, '2024-10-23 09:00+00', '2024-10-23 12:00+00', '2024-10-23 11:55+00'),
(2,  6, 'delivered', 'standard',   26, 364.00,  10.00,   0.00, '2024-11-06 08:30+00', '2024-11-06 11:00+00', '2024-11-06 11:05+00'),
(3,  4, 'delivered', 'scheduled',  50, 850.00,  15.00,   0.00, '2024-11-13 09:00+00', '2024-11-13 12:00+00', '2024-11-13 12:00+00'),
(19, 4, 'delivered', 'express',    88,1496.00,  30.00,   0.00, '2024-11-20 10:00+00', '2024-11-20 12:00+00', '2024-11-20 12:10+00'),
(1,  8, 'delivered', 'scheduled',  62,1054.00,  20.00,   0.00, '2024-12-04 09:00+00', '2024-12-04 12:00+00', '2024-12-04 12:05+00'),
(5,  1, 'delivered', 'express',   110,1705.00,  40.00,   0.00, '2024-12-11 09:30+00', '2024-12-11 12:00+00', '2024-12-11 12:20+00'),
(11, 4, 'delivered', 'express',   125,2125.00,  45.00,   0.00, '2024-12-18 10:00+00', '2024-12-18 12:30+00', '2024-12-18 12:25+00'),
-- Cancelled orders (realistic ~8% cancellation rate)
(6,  3, 'cancelled', 'standard',   10, 140.00,  10.00,   0.00, '2023-05-10 09:00+00', '2023-05-10 11:30+00', NULL),
(9, 10, 'cancelled', 'standard',   20, 260.00,  10.00,   0.00, '2023-07-14 08:30+00', '2023-07-14 11:00+00', NULL),
(12, 7, 'cancelled', 'standard',   15, 195.00,  10.00,   0.00, '2023-09-05 09:00+00', '2023-09-05 11:30+00', NULL),
(16, 3, 'cancelled', 'standard',   18, 234.00,  10.00,   0.00, '2024-02-08 08:00+00', '2024-02-08 11:00+00', NULL),
(18, 7, 'cancelled', 'standard',   12, 156.00,  10.00,   0.00, '2024-04-30 09:00+00', '2024-04-30 11:30+00', NULL),
(20, 15,'cancelled', 'standard',    8,  96.00,  10.00,   0.00, '2024-07-02 08:00+00', '2024-07-02 11:00+00', NULL);

-- Update cancelled_at for cancelled orders
UPDATE orders SET cancelled_at = placed_at + INTERVAL '2 hours' WHERE order_status = 'cancelled';


-- -----------------------------------------------------------------------------
-- order_items  (sample line items for the first 12 delivered orders)
-- A real pipeline would have items for every order; this demonstrates the
-- schema and enables per-category revenue queries.
-- -----------------------------------------------------------------------------
INSERT INTO order_items (order_id, item_name, category, unit_price_usd, quantity) VALUES
-- order 1 (Boston Box Lunch, 45 headcount)
(1, 'Club Sandwich Box',        'Entree',   12.00, 30),
(1, 'Caesar Salad Box',         'Entree',    9.00, 15),
(1, 'Bottled Water 12-pack',    'Beverage',  8.00,  3),
-- order 2 (Bella Cucina, 60 headcount)
(2, 'Chicken Marsala',          'Entree',   14.00, 40),
(2, 'Penne Arrabbiata',         'Entree',   11.00, 20),
(2, 'Tiramisu Slice',           'Dessert',   5.00, 20),
(2, 'Sparkling Water 12-pack',  'Beverage',  9.00,  3),
-- order 3 (Taqueria Del Sol, 20 headcount)
(3, 'Taco Bar Package',         'Entree',   11.50, 20),
(3, 'Chips & Salsa',            'Side',      2.50, 20),
(3, 'Mexican Coke 6-pack',      'Beverage',  7.00,  2),
-- order 4 (Mediterranean Table, 35 headcount)
(4, 'Mezze Platter per person', 'Entree',   13.00, 25),
(4, 'Falafel Wrap',             'Entree',   10.00, 10),
(4, 'Baklava Tray',             'Dessert',   3.50, 20),
-- order 5 (Bella Cucina, 80 headcount)
(5, 'Pasta Primavera',          'Entree',   12.00, 50),
(5, 'Chicken Piccata',          'Entree',   15.00, 30),
(5, 'Garden Salad',             'Side',      4.00, 40),
(5, 'Cannoli',                  'Dessert',   4.50, 20),
-- order 6 (Green Garden, 15 headcount)
(6, 'Buddha Bowl',              'Entree',   11.00, 15),
(6, 'Kombucha 6-pack',          'Beverage',  9.00,  2),
-- order 7 (Harbor Fresh, 12 headcount)
(7, 'Turkey & Avocado Wrap',    'Entree',   12.00, 12),
(7, 'Kettle Chips',             'Side',      2.00, 12),
-- order 8 (Boston Box Lunch, 100 headcount)
(8, 'Assorted Deli Boxes',      'Entree',   13.50, 70),
(8, 'Veggie Wrap Box',          'Entree',   11.00, 30),
(8, 'Brownie Platter',          'Dessert',   3.00, 40),
(8, 'Lemonade Jug (1gal)',      'Beverage', 12.00,  5);


-- -----------------------------------------------------------------------------
-- delivery_events  (operational log for a subset of orders)
-- -----------------------------------------------------------------------------
INSERT INTO delivery_events (order_id, event_type, event_ts, notes) VALUES
(1,  'dispatched',  '2023-01-10 10:45+00', NULL),
(1,  'arrived',     '2023-01-10 11:20+00', NULL),
(1,  'completed',   '2023-01-10 11:25+00', 'All items delivered, client signed off'),
(2,  'dispatched',  '2023-01-24 11:00+00', NULL),
(2,  'arrived',     '2023-01-24 12:05+00', NULL),
(2,  'completed',   '2023-01-24 12:10+00', '5-min delay — elevator wait at client building'),
(5,  'dispatched',  '2023-02-28 11:30+00', NULL),
(5,  'arrived',     '2023-02-28 12:40+00', NULL),
(5,  'completed',   '2023-02-28 12:45+00', 'Traffic on I-93 caused 15-min delay'),
(8,  'dispatched',  '2023-03-22 11:00+00', NULL),
(8,  'arrived',     '2023-03-22 11:50+00', NULL),
(8,  'completed',   '2023-03-22 11:55+00', NULL);


-- -----------------------------------------------------------------------------
-- promo_orders  (link orders to promotions that were applied)
-- -----------------------------------------------------------------------------
INSERT INTO promo_orders (promo_id, order_id) VALUES
(2, 2),   -- ENT100 applied to order 2
(2, 5),   -- ENT100 applied to order 5
(2, 8),   -- ENT100 applied to order 8
(1, 4),   -- WELCOME25 applied to order 4
(1, 6),   -- WELCOME25 applied to order 6
(1, 7),   -- WELCOME25 applied to order 7
(4, 18),  -- SUMMER15
(4, 19),  -- SUMMER15
(4, 20),  -- SUMMER15
(5, 27),  -- Q4BOOST
(5, 28),  -- Q4BOOST
(5, 29),  -- Q4BOOST
(6, 36),  -- NY2024
(6, 37),  -- NY2024
(6, 38),  -- NY2024
(7, 46),  -- SPRING20
(7, 47),  -- SPRING20
(8, 55),  -- LOYAL50
(8, 56),  -- LOYAL50
(8, 57);  -- LOYAL50
