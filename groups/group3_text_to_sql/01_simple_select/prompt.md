# Text-to-SQL: Basic SELECT Queries

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "Show me all employees" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query.
- It should execute the query and print the results to stdout, one row per line.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.

## Database Schema

The database you will be tested against has the following schema:

```sql
CREATE TABLE employees (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    department TEXT NOT NULL,
    salary REAL NOT NULL,
    hire_date TEXT NOT NULL
);
```

The table contains employee records with fields for name, department, salary, and hire date.

## Examples of Questions

- "Show me all employees"
- "List employees in the Engineering department"
- "Who has a salary greater than 80000?"
- "Show all employees hired after 2023-01-01"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible, but the important thing is that the data values are visible in the output.
