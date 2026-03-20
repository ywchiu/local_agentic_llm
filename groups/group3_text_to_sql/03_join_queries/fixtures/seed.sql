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

INSERT INTO students (id, name, grade_level) VALUES
(1, 'Amy Turner', 10),
(2, 'Brian Hall', 10),
(3, 'Chloe Adams', 11),
(4, 'Derek Fox', 11),
(5, 'Elena Cruz', 12),
(6, 'Finn Brooks', 12),
(7, 'Gina Patel', 10),
(8, 'Hugo Rivera', 11);

INSERT INTO courses (id, course_name, teacher) VALUES
(1, 'Math', 'Mr. Thompson'),
(2, 'Science', 'Ms. Garcia'),
(3, 'English', 'Mrs. Lee'),
(4, 'History', 'Mr. Davis');

INSERT INTO enrollments (student_id, course_id, score) VALUES
(1, 1, 92.0),
(1, 2, 88.5),
(2, 1, 85.0),
(2, 3, 91.0),
(3, 2, 94.5),
(3, 4, 87.0),
(4, 1, 78.0),
(4, 3, 82.5),
(5, 2, 96.0),
(5, 4, 90.0),
(6, 1, 88.0),
(6, 3, 85.5),
(7, 2, 91.0),
(7, 4, 89.0),
(8, 1, 76.0);
