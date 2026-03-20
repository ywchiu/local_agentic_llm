CREATE TABLE employees (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    department TEXT NOT NULL,
    salary REAL NOT NULL,
    hire_date TEXT NOT NULL
);

INSERT INTO employees (id, name, department, salary, hire_date) VALUES
(1, 'Alice Johnson', 'Engineering', 95000, '2022-03-15'),
(2, 'Bob Smith', 'Engineering', 88000, '2021-07-01'),
(3, 'Carol Williams', 'Engineering', 102000, '2020-11-20'),
(4, 'David Brown', 'Marketing', 75000, '2023-01-10'),
(5, 'Eva Martinez', 'Marketing', 78000, '2022-06-15'),
(6, 'Frank Lee', 'Marketing', 71000, '2023-09-01'),
(7, 'Grace Kim', 'Sales', 82000, '2021-04-20'),
(8, 'Henry Chen', 'Sales', 79000, '2022-08-30'),
(9, 'Irene Davis', 'Sales', 85000, '2020-02-14'),
(10, 'Jack Wilson', 'Sales', 77000, '2023-05-22');
