import os
os.environ.setdefault("RUNFUEL_BASE_URL", "https://runfuel-test.example")

import os
import unittest

from api.index import BLOCKED_MFP_TOOLS, GARMIN_READ_TOOLS, MFP_READ_TOOLS, authorized


class AuthenticationTests(unittest.TestCase):
    def test_missing_config_fails_closed(self):
        self.assertFalse(authorized([(b"authorization", b"Bearer token")], None))

    def test_missing_header_is_rejected(self):
        self.assertFalse(authorized([], "secret"))

    def test_wrong_token_is_rejected(self):
        self.assertFalse(authorized([(b"authorization", b"Bearer wrong")], "secret"))

    def test_valid_bearer_token_is_accepted(self):
        self.assertTrue(authorized([(b"authorization", b"Bearer secret")], "secret"))

    def test_non_bearer_scheme_is_rejected(self):
        self.assertFalse(authorized([(b"authorization", b"Basic secret")], "secret"))


class ReadOnlyAllowlistTests(unittest.TestCase):
    def test_known_mutating_mfp_tools_are_not_allowlisted(self):
        self.assertTrue(set(MFP_READ_TOOLS).isdisjoint(BLOCKED_MFP_TOOLS))

    def test_download_tool_is_not_exposed(self):
        self.assertNotIn("garmin_download_activity", GARMIN_READ_TOOLS)

    def test_profile_tool_is_not_exposed_but_activity_detail_remains_available(self):
        self.assertNotIn("garmin_get_profile", GARMIN_READ_TOOLS)
        self.assertIn("garmin_get_activity", GARMIN_READ_TOOLS)
        self.assertIn("garmin_search_activities", GARMIN_READ_TOOLS)

    def test_expected_read_tools_are_allowlisted(self):
        self.assertEqual(
            set(MFP_READ_TOOLS) | {"fitness_check_connection"},
            {
                "fitness_get_day",
                "fitness_search_food",
                "fitness_get_note",
                "fitness_get_trends",
                "fitness_bulk_export",
                "fitness_list_food_pins",
                "fitness_check_connection",
            },
        )

    def test_mfp_exercise_tools_are_not_allowlisted(self):
        self.assertNotIn("fitness_get_exercise", MFP_READ_TOOLS)
        self.assertNotIn("fitness_get_exercise_entries", MFP_READ_TOOLS)


if __name__ == "__main__":
    unittest.main()
