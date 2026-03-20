CREATE TABLE books (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    genre TEXT NOT NULL,
    rating REAL NOT NULL,
    published_year INTEGER NOT NULL,
    pages INTEGER NOT NULL
);

INSERT INTO books (id, title, author, genre, rating, published_year, pages) VALUES
(1, 'The Midnight Library', 'Matt Haig', 'Fiction', 4.2, 2020, 288),
(2, 'Project Hail Mary', 'Andy Weir', 'Science Fiction', 4.8, 2021, 496),
(3, 'Klara and the Sun', 'Kazuo Ishiguro', 'Fiction', 3.9, 2021, 320),
(4, 'The Vanishing Half', 'Brit Bennett', 'Fiction', 4.1, 2020, 352),
(5, 'Dune', 'Frank Herbert', 'Science Fiction', 4.6, 1965, 688),
(6, 'The Great Gatsby', 'F. Scott Fitzgerald', 'Classic', 4.0, 1925, 180),
(7, 'To Kill a Mockingbird', 'Harper Lee', 'Classic', 4.5, 1960, 336),
(8, 'Sapiens', 'Yuval Noah Harari', 'Non-Fiction', 4.4, 2011, 464),
(9, 'Educated', 'Tara Westover', 'Memoir', 4.7, 2018, 352),
(10, 'Atomic Habits', 'James Clear', 'Self-Help', 4.3, 2018, 320),
(11, 'The Song of Achilles', 'Madeline Miller', 'Fiction', 4.5, 2012, 416),
(12, 'Tomorrow and Tomorrow and Tomorrow', 'Gabrielle Zevin', 'Fiction', 4.3, 2022, 416),
(13, 'Demon Copperhead', 'Barbara Kingsolver', 'Fiction', 4.6, 2022, 560),
(14, 'Lessons in Chemistry', 'Bonnie Garmus', 'Fiction', 4.2, 2022, 400),
(15, 'Sea of Tranquility', 'Emily St. John Mandel', 'Science Fiction', 3.8, 2022, 272);
