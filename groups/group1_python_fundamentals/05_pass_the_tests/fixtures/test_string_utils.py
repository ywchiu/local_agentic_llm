import pytest
from string_utils import (
    reverse_words,
    camel_to_snake,
    truncate,
    count_vowels,
    is_palindrome,
    title_case,
)


def test_reverse_words_simple():
    assert reverse_words("hello world") == "world hello"


def test_reverse_words_single():
    assert reverse_words("hello") == "hello"


def test_reverse_words_extra_spaces():
    assert reverse_words("  hello   world  ") == "world hello"


def test_camel_to_snake_simple():
    assert camel_to_snake("helloWorld") == "hello_world"


def test_camel_to_snake_multiple():
    assert camel_to_snake("myVariableName") == "my_variable_name"


def test_camel_to_snake_consecutive_caps():
    assert camel_to_snake("parseHTTPResponse") == "parse_http_response"


def test_truncate_short():
    assert truncate("hello", 10) == "hello"


def test_truncate_exact():
    assert truncate("hello world", 8) == "hello..."


def test_count_vowels():
    assert count_vowels("hello world") == 3


def test_count_vowels_caps():
    assert count_vowels("AEIOU") == 5


def test_is_palindrome():
    assert is_palindrome("racecar") is True


def test_is_palindrome_spaces():
    assert is_palindrome("race car") is False


def test_is_palindrome_mixed_case():
    assert is_palindrome("RaceCar") is True


def test_title_case_simple():
    assert title_case("hello world") == "Hello World"


def test_title_case_with_small_words():
    assert title_case("the quick brown fox") == "The Quick Brown Fox"
