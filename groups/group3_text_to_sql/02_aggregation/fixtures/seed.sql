CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    customer_name TEXT NOT NULL,
    product TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    price REAL NOT NULL,
    order_date TEXT NOT NULL
);

INSERT INTO orders (id, customer_name, product, quantity, price, order_date) VALUES
(1, 'Alice', 'Widget A', 3, 25.00, '2025-01-05'),
(2, 'Bob', 'Widget B', 1, 50.00, '2025-01-12'),
(3, 'Carol', 'Gadget X', 2, 75.00, '2025-02-03'),
(4, 'Alice', 'Widget A', 5, 25.00, '2025-02-14'),
(5, 'David', 'Gadget Y', 1, 150.00, '2025-03-01'),
(6, 'Eva', 'Widget B', 4, 50.00, '2025-03-10'),
(7, 'Bob', 'Gadget X', 2, 75.00, '2025-03-15'),
(8, 'Frank', 'Widget A', 10, 25.00, '2025-04-01'),
(9, 'Carol', 'Gadget Y', 3, 150.00, '2025-04-12'),
(10, 'Grace', 'Widget B', 2, 50.00, '2025-05-05'),
(11, 'Henry', 'Gadget X', 1, 75.00, '2025-05-20'),
(12, 'Alice', 'Widget A', 6, 25.00, '2025-06-01'),
(13, 'David', 'Gadget Y', 2, 150.00, '2025-06-15'),
(14, 'Eva', 'Widget B', 3, 50.00, '2025-07-01'),
(15, 'Frank', 'Gadget X', 4, 75.00, '2025-07-10');
