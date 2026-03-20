CREATE TABLE events (
    id INTEGER PRIMARY KEY,
    event_name TEXT NOT NULL,
    venue TEXT NOT NULL,
    event_date TEXT NOT NULL,
    attendees INTEGER NOT NULL
);

INSERT INTO events (id, event_name, venue, event_date, attendees) VALUES
(1, 'Spring Gala', 'Grand Ballroom', '2025-03-20', 250),
(2, 'Tech Conference', 'Convention Center', '2025-05-15', 500),
(3, 'Summer Concert', 'City Park', '2025-07-04', 1200),
(4, 'Art Exhibition', 'Modern Gallery', '2025-08-22', 180),
(5, 'Charity Run', 'Riverside Track', '2025-09-10', 350),
(6, 'Film Festival', 'Downtown Cinema', '2025-10-30', 420),
(7, 'Holiday Market', 'Town Square', '2025-12-15', 800),
(8, 'New Year Bash', 'Grand Ballroom', '2026-01-01', 600),
(9, 'Winter Workshop', 'Community Center', '2026-01-18', 90),
(10, 'Science Fair', 'University Hall', '2026-02-14', 275),
(11, 'Book Club Meetup', 'City Library', '2026-03-05', 45),
(12, 'Music Awards', 'Concert Arena', '2026-04-20', 1500);
