# Text-to-SQL: Complex Analytics

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "Show total deposits and withdrawals per account" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query.
- It should execute the query and print the results to stdout, one row per line.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.
- The script must handle complex analytical queries: GROUP BY with multiple aggregations, SUM with conditional logic, date-based grouping, and multi-table joins with aggregates.

## Database Schema

The database you will be tested against has the following schema:

```sql
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
```

The `accounts` table holds account info. The `transactions` table records deposits and withdrawals with dates. The `type` column in transactions is either 'deposit' or 'withdrawal'.

## Examples of Questions

- "Show total deposits and withdrawals per account"
- "Which account has the highest total deposits?"
- "What is the total transaction amount per month?"
- "How many transactions does each account have?"
- "What is the average deposit amount?"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible, but the important thing is that the data values are visible in the output.
