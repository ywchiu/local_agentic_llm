# Text-to-SQL: Date Filtering Queries

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "Show events in January 2026" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query, handling date filtering, date ranges, and ordering by dates.
- It should execute the query and print the results to stdout.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.
- Dates are stored as TEXT in ISO format (YYYY-MM-DD) and can be compared as strings in SQLite.

## Database Schema

The database you will be tested against has the following schema:

```sql
CREATE TABLE events (
    id INTEGER PRIMARY KEY,
    event_name TEXT NOT NULL,
    venue TEXT NOT NULL,
    event_date TEXT NOT NULL,
    attendees INTEGER NOT NULL
);
```

The table contains event records with a name, venue, date (YYYY-MM-DD format), and number of attendees.

## Examples of Questions

- "Show events in January 2026"
- "List events between 2025-06-01 and 2025-12-31"
- "What was the most recent event?"
- "Which event had the most attendees?"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible.
