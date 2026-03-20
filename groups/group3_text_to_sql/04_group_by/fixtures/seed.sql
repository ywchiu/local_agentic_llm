CREATE TABLE sales (
    id INTEGER PRIMARY KEY,
    salesperson TEXT NOT NULL,
    region TEXT NOT NULL,
    amount REAL NOT NULL,
    sale_date TEXT NOT NULL
);

INSERT INTO sales (id, salesperson, region, amount, sale_date) VALUES
(1, 'Alice', 'North', 250.00, '2025-01-10'),
(2, 'Bob', 'South', 430.00, '2025-01-15'),
(3, 'Carol', 'East', 180.00, '2025-02-01'),
(4, 'Alice', 'North', 320.00, '2025-02-10'),
(5, 'David', 'South', 510.00, '2025-02-20'),
(6, 'Bob', 'East', 290.00, '2025-03-05'),
(7, 'Carol', 'North', 150.00, '2025-03-12'),
(8, 'Alice', 'South', 480.00, '2025-03-25'),
(9, 'David', 'East', 370.00, '2025-04-02'),
(10, 'Bob', 'North', 220.00, '2025-04-15'),
(11, 'Carol', 'South', 340.00, '2025-04-28'),
(12, 'Alice', 'East', 195.00, '2025-05-10'),
(13, 'David', 'North', 415.00, '2025-05-22'),
(14, 'Bob', 'South', 360.00, '2025-06-01'),
(15, 'Carol', 'East', 275.00, '2025-06-15'),
(16, 'Alice', 'North', 310.00, '2025-07-01'),
(17, 'David', 'South', 440.00, '2025-07-12'),
(18, 'Bob', 'East', 185.00, '2025-07-25'),
(19, 'Carol', 'North', 290.00, '2025-08-05'),
(20, 'David', 'East', 525.00, '2025-08-18');
