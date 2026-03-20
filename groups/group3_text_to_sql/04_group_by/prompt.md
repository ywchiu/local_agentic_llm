# Text-to-SQL: GROUP BY and HAVING Queries

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "What are the total sales by region?" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query, including GROUP BY and HAVING clauses as needed.
- It should execute the query and print the results to stdout.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.

## Database Schema

The database you will be tested against has the following schema:

```sql
CREATE TABLE sales (
    id INTEGER PRIMARY KEY,
    salesperson TEXT NOT NULL,
    region TEXT NOT NULL,
    amount REAL NOT NULL,
    sale_date TEXT NOT NULL
);
```

The table contains sales records with a salesperson name, region, dollar amount, and date.

## Examples of Questions

- "What are the total sales by region?"
- "Which salespeople have total sales over 1000?"
- "How many sales did each salesperson make?"
- "What is the average sale amount per region?"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible.
