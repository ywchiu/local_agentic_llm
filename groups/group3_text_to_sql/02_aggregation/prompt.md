# Text-to-SQL: Aggregation Queries

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "How many orders are there?" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query, including aggregation functions like COUNT, SUM, AVG, MIN, MAX.
- It should execute the query and print the results to stdout.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.

## Database Schema

The database you will be tested against has the following schema:

```sql
CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    customer_name TEXT NOT NULL,
    product TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    price REAL NOT NULL,
    order_date TEXT NOT NULL
);
```

The table contains order records. Note that the total revenue for an order is `quantity * price`.

## Examples of Questions

- "How many orders are there?"
- "What is the total revenue?" (meaning SUM of quantity * price)
- "What is the average order price?"
- "What is the maximum order quantity?"

## Output Format

Print the result clearly to stdout. For single-value results (like a count or sum), just print the number. For multi-row results, print one row per line with values separated by `|` or clearly displayed.
