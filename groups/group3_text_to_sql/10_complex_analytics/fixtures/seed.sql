CREATE TABLE accounts (
    id INTEGER PRIMARY KEY,
    owner_name TEXT NOT NULL,
    account_type TEXT NOT NULL,
    balance REAL NOT NULL
);

CREATE TABLE transactions (
    id INTEGER PRIMARY KEY,
    account_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    amount REAL NOT NULL,
    transaction_date TEXT NOT NULL,
    FOREIGN KEY (account_id) REFERENCES accounts(id)
);

INSERT INTO accounts (id, owner_name, account_type, balance) VALUES
(1, 'Alice Martin', 'checking', 5200.00),
(2, 'Bob Taylor', 'savings', 12000.00),
(3, 'Carol White', 'checking', 3100.00),
(4, 'Dan Green', 'savings', 8500.00),
(5, 'Eva Black', 'checking', 1500.00);

INSERT INTO transactions (id, account_id, type, amount, transaction_date) VALUES
(1, 1, 'deposit', 2000.00, '2024-01-15'),
(2, 1, 'withdrawal', 500.00, '2024-01-20'),
(3, 1, 'deposit', 1500.00, '2024-02-10'),
(4, 1, 'withdrawal', 300.00, '2024-02-28'),
(5, 1, 'deposit', 1000.00, '2024-03-05'),
(6, 2, 'deposit', 5000.00, '2024-01-05'),
(7, 2, 'deposit', 3000.00, '2024-01-25'),
(8, 2, 'withdrawal', 1000.00, '2024-02-15'),
(9, 2, 'deposit', 2000.00, '2024-03-10'),
(10, 2, 'withdrawal', 500.00, '2024-03-20'),
(11, 3, 'deposit', 1500.00, '2024-01-10'),
(12, 3, 'withdrawal', 700.00, '2024-01-30'),
(13, 3, 'deposit', 800.00, '2024-02-20'),
(14, 3, 'withdrawal', 200.00, '2024-03-01'),
(15, 3, 'deposit', 1200.00, '2024-03-15'),
(16, 4, 'deposit', 3000.00, '2024-01-12'),
(17, 4, 'withdrawal', 1500.00, '2024-02-05'),
(18, 4, 'deposit', 4000.00, '2024-02-22'),
(19, 4, 'withdrawal', 800.00, '2024-03-08'),
(20, 4, 'deposit', 1000.00, '2024-03-25'),
(21, 5, 'deposit', 500.00, '2024-01-08'),
(22, 5, 'withdrawal', 200.00, '2024-01-22'),
(23, 5, 'deposit', 750.00, '2024-02-14'),
(24, 5, 'withdrawal', 300.00, '2024-03-03'),
(25, 5, 'deposit', 600.00, '2024-03-18');
