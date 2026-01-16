"""
Example test file for the project.

This file demonstrates how to structure unit tests using pytest.
"""

import unittest


class TestExample(unittest.TestCase):
    """Example test class."""

    def setUp(self):
        """Set up test fixtures."""
        self.test_value = 5

    def test_addition(self):
        """Test basic addition."""
        result = self.test_value + 3
        self.assertEqual(result, 8)

    def test_subtraction(self):
        """Test basic subtraction."""
        result = self.test_value - 2
        self.assertEqual(result, 3)

    def test_multiplication(self):
        """Test basic multiplication."""
        result = self.test_value * 2
        self.assertEqual(result, 10)

    def tearDown(self):
        """Clean up after tests."""
        self.test_value = None


if __name__ == '__main__':
    unittest.main()
