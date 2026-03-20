# Text-to-SQL: NULL Handling

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "Which employees have no bonus?" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query.
- It should execute the query and print the results to stdout, one row per line.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.
- The script must handle NULL values properly: IS NULL, IS NOT NULL, COALESCE, and counting/filtering on nullable columns.

## Database Schema

The database you will be tested against has the following schema:

```sql
CREATE TABLE employees (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    department TEXT NOT NULL,
    manager_id INTEGER,
    bonus REAL
);
```

The `employees` table has nullable fields: `manager_id` (NULL means no manager, i.e., top-level) and `bonus` (NULL means no bonus assigned). Some employees have a manager, some do not. Some have a bonus, some do not.

## Examples of Questions

- "Which employees have no bonus?"
- "List employees who have a manager"
- "How many employees don't have a bonus?"
- "Show employees with no manager"
- "What is the average bonus?"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible, but the important thing is that the data values are visible in the output.
