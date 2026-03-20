# Text-to-SQL: Subqueries and Nested Queries

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "What is the most expensive product?" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query.
- It should execute the query and print the results to stdout, one row per line.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.
- The script must handle subqueries and nested queries (e.g., finding max/min values, filtering with IN clauses, comparisons against aggregates).

## Database Schema

The database you will be tested against has the following schema:

```sql
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
```

The `products` table contains product details with name, category, and price. The `inventory` table tracks how many units of each product are stocked in each warehouse.

## Examples of Questions

- "What is the most expensive product?"
- "Which products are stocked in the NYC warehouse?"
- "Which products cost more than the average price?"
- "Show all products in the Electronics category"
- "What products have inventory in multiple warehouses?"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible, but the important thing is that the data values are visible in the output.
