# Text-to-SQL: Ordering and Limits

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "What are the top 3 highest rated books?" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query.
- It should execute the query and print the results to stdout, one row per line.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.
- The script must handle ORDER BY (ascending and descending), LIMIT, and filtering with comparisons combined with sorting.

## Database Schema

The database you will be tested against has the following schema:

```sql
CREATE TABLE books (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    genre TEXT NOT NULL,
    rating REAL NOT NULL,
    published_year INTEGER NOT NULL,
    pages INTEGER NOT NULL
);
```

The table contains book records with title, author, genre, rating (0-5 scale), published year, and page count.

## Examples of Questions

- "What are the top 3 highest rated books?"
- "Show the 5 longest books by page count"
- "List books published after 2020 ordered by year"
- "What is the lowest rated book?"
- "Show all books sorted by title"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible, but the important thing is that the data values are visible in the output.
