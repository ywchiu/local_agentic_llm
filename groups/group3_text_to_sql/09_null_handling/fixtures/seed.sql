CREATE TABLE employees (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    department TEXT NOT NULL,
    manager_id INTEGER,
    bonus REAL
);

INSERT INTO employees (id, name, department, manager_id, bonus) VALUES
(1, 'Alice Chen', 'Engineering', NULL, 5000.00),
(2, 'Bob Park', 'Engineering', 1, 3000.00),
(3, 'Carol Davis', 'Engineering', 1, NULL),
(4, 'Dan Wilson', 'Marketing', NULL, 2500.00),
(5, 'Eva Lopez', 'Marketing', 4, NULL),
(6, 'Frank Kim', 'Marketing', 4, 1500.00),
(7, 'Grace Hall', 'Sales', NULL, NULL),
(8, 'Henry Adams', 'Sales', 7, 4000.00),
(9, 'Irene Scott', 'Sales', 7, NULL),
(10, 'Jack Turner', 'Sales', 7, 2000.00);
