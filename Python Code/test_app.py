import unittest
import json
from app import app

class TestApp(unittest.TestCase):

    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_add_visitor(self):
        response = self.app.post('/visitors', json={'name': 'John Doe'})
        data = json.loads(response.data.decode())
        self.assertEqual(response.status_code, 201)
        self.assertEqual(data['message'], 'Visitor added successfully')

    def test_get_visitors(self):
        response = self.app.get('/visitors')
        data = json.loads(response.data.decode())
        self.assertEqual(response.status_code, 200)
        self.assertTrue('visitors' in data)
        self.assertIsInstance(data['visitors'], list)

if __name__ == '__main__':
    unittest.main()
