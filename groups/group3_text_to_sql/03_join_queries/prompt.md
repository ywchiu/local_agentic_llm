# Text-to-SQL: JOIN Queries

Build a Python script called `text_to_sql.py` that takes a natural language question and a SQLite database path as command-line arguments, translates the question into a SQL query, executes it against the database, and prints the results.

## Usage

```
python text_to_sql.py "Which students are enrolled in Math?" /path/to/database.db
```

## Requirements

- The script should accept exactly two command-line arguments: the natural language question (as a string) and the path to a SQLite database file.
- It should analyze the database schema automatically (inspect tables and columns) to understand the structure.
- It should translate the natural language question into an appropriate SQL query, including JOINs across multiple tables when needed.
- It should execute the query and print the results to stdout.
- The script should work with any database schema, not just hardcoded tables.
- No external API calls or LLM usage -- use heuristic/keyword-based translation.

## Database Schema

The database you will be tested against has the following schema:

```sql
CREATE TABLE students (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    grade_level INTEGER NOT NULL
);

CREATE TABLE courses (
    id INTEGER PRIMARY KEY,
    course_name TEXT NOT NULL,
    teacher TEXT NOT NULL
);

CREATE TABLE enrollments (
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    score REAL,
    FOREIGN KEY (student_id) REFERENCES students(id),
    FOREIGN KEY (course_id) REFERENCES courses(id)
);
```

The database models a school with students, courses, and enrollments linking them. Each enrollment may have a score.

## Examples of Questions

- "Which students are enrolled in Math?"
- "Show each student's name and their course names"
- "How many students are in each course?"
- "What is the average score in Science?"

## Output Format

Print each result row on its own line. Column values should be separated by `|` or displayed clearly. Include column headers if possible.
