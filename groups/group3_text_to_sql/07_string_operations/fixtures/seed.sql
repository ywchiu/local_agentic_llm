CREATE TABLE contacts (
    id INTEGER PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    city TEXT NOT NULL
);

INSERT INTO contacts (id, first_name, last_name, email, phone, city) VALUES
(1, 'Alice', 'Smith', 'alice.smith@gmail.com', '212-555-1001', 'New York'),
(2, 'Bob', 'Johnson', 'bob.johnson@yahoo.com', '310-555-1002', 'Los Angeles'),
(3, 'Carol', 'Sanders', 'carol.sanders@gmail.com', '312-555-1003', 'Chicago'),
(4, 'Dan', 'Stevens', 'dan.stevens@outlook.com', '212-555-1004', 'New York'),
(5, 'Eva', 'Brown', 'eva.brown@gmail.com', '415-555-1005', 'San Francisco'),
(6, 'Frank', 'Sullivan', 'frank.sullivan@company.com', '212-555-1006', 'New York'),
(7, 'Grace', 'Lee', 'grace.lee@yahoo.com', '310-555-1007', 'Los Angeles'),
(8, 'Henry', 'Martinez', 'henry.m@gmail.com', '713-555-1008', 'Houston'),
(9, 'Irene', 'Taylor', 'irene.t@outlook.com', '312-555-1009', 'Chicago'),
(10, 'James', 'Scott', 'james.scott@gmail.com', '206-555-1010', 'Seattle'),
(11, 'Karen', 'White', 'karen.w@company.com', '415-555-1011', 'San Francisco'),
(12, 'Leo', 'Simmons', 'leo.simmons@gmail.com', '212-555-1012', 'New York');
