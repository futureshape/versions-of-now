#!/usr/bin/env python3

import datetime as dt
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import speaking_clock


class PhraseTests(unittest.TestCase):
    def phrase(self, hour, minute, second, **kwargs):
        target = dt.datetime(2026, 6, 23, hour, minute, second)
        return speaking_clock.build_announcement(target, **kwargs)

    def test_exact_hour_uses_oclock_precisely(self):
        self.assertEqual(
            self.phrase(0, 0, 0),
            "At the third stroke, the time will be twelve o'clock precisely.",
        )

    def test_exact_minute_uses_precisely(self):
        self.assertEqual(
            self.phrase(13, 5, 0),
            "At the third stroke, the time will be one oh five precisely.",
        )

    def test_ten_second_interval_phrase(self):
        self.assertEqual(
            self.phrase(23, 46, 10),
            "At the third stroke, the time will be eleven forty six and ten seconds.",
        )

    def test_zero_minute_with_seconds_uses_oclock(self):
        self.assertEqual(
            self.phrase(12, 0, 50),
            "At the third stroke, the time will be twelve o'clock and fifty seconds.",
        )

    def test_source_label(self):
        self.assertEqual(
            self.phrase(9, 8, 30, source_label="from Versions of Now"),
            "At the third stroke, the time from Versions of Now will be nine oh eight and thirty seconds.",
        )

    def test_24_hour_mode(self):
        self.assertEqual(
            self.phrase(21, 15, 0, hour_mode="24"),
            "At the third stroke, the time will be twenty one fifteen precisely.",
        )


class SchedulingTests(unittest.TestCase):
    def test_next_boundary(self):
        self.assertEqual(speaking_clock.next_boundary(100.1, 10), 110)
        self.assertEqual(speaking_clock.next_boundary(110.0, 10), 110)

    def test_interval_validation(self):
        self.assertEqual(speaking_clock.interval_value("10"), 10)
        with self.assertRaises(Exception):
            speaking_clock.interval_value("7")


if __name__ == "__main__":
    unittest.main()
