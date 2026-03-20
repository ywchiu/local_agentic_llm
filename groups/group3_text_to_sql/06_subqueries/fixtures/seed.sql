CREATE TABLE products (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    price REAL NOT NULL
);

CREATE TABLE inventory (
    product_id INTEGER NOT NULL,
    warehouse TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id)
);

INSERT INTO products (id, name, category, price) VALUES
(1, 'Laptop Pro', 'Electronics', 1299.99),
(2, 'Wireless Mouse', 'Electronics', 29.99),
(3, 'USB-C Cable', 'Electronics', 12.99),
(4, 'Standing Desk', 'Furniture', 549.00),
(5, 'Ergonomic Chair', 'Furniture', 399.00),
(6, 'Monitor 27in', 'Electronics', 449.99),
(7, 'Keyboard Mechanical', 'Electronics', 89.99),
(8, 'Desk Lamp', 'Furniture', 45.00),
(9, 'Webcam HD', 'Electronics', 79.99),
(10, 'Notebook Pack', 'Office Supplies', 15.99);

INSERT INTO inventory (product_id, warehouse, quantity) VALUES
(1, 'NYC', 25),
(1, 'LAX', 30),
(1, 'CHI', 15),
(2, 'NYC', 100),
(2, 'LAX', 80),
(3, 'NYC', 200),
(3, 'CHI', 150),
(4, 'LAX', 10),
(4, 'CHI', 8),
(5, 'NYC', 12),
(5, 'LAX', 15),
(6, 'NYC', 40),
(6, 'CHI', 35),
(7, 'NYC', 60),
(7, 'LAX', 45),
(8, 'CHI', 50),
(9, 'NYC', 30),
(9, 'LAX', 25),
(10, 'NYC', 500),
(10, 'LAX', 300),
(10, 'CHI', 400);
