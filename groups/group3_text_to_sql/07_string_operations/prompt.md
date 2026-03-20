# Text-to-SQL: String Operations and Pattern Matching

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "Find contacts whose last name starts with S" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query.
- It should execute the query and print the results to stdout, one row per line.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.
- The script must handle string operations: LIKE patterns, partial matching, starts with, contains, and filtering by string column values.

## Database Schema

The database you will be tested against has the following schema:

```sql
CREATE TABLE contacts (
    id INTEGER PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    city TEXT NOT NULL
);
```

The table contains contact records with first name, last name, email, phone, and city fields.

## Examples of Questions

- "Find contacts whose last name starts with 'S'"
- "Show all contacts in New York"
- "List contacts with gmail addresses"
- "Who has a phone number starting with 212?"
- "Find contacts whose first name contains 'an'"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible, but the important thing is that the data values are visible in the output.
