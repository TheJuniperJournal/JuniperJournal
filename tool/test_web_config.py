import base64, json, unittest
from web_config import public_config
class WebConfigTest(unittest.TestCase):
    def test_only_public_values_are_exported(self):
        result = public_config('SUPABASE_URL=https://example.supabase.co\nSUPABASE_KEY=sb_publishable_test\nPRIVATE_TOKEN=hidden')
        self.assertEqual(set(result), {'SUPABASE_URL', 'SUPABASE_KEY'})
    def test_secret_key_is_rejected(self):
        with self.assertRaises(ValueError):
            public_config('SUPABASE_URL=https://example.supabase.co\nSUPABASE_KEY=sb_secret_test')
    def test_service_role_jwt_is_rejected(self):
        payload = base64.urlsafe_b64encode(json.dumps({'role': 'service_role'}).encode()).decode().rstrip('=')
        with self.assertRaises(ValueError):
            public_config(json.dumps({'SUPABASE_URL': 'https://example.supabase.co', 'SUPABASE_KEY': f'header.{payload}.signature'}))
if __name__ == '__main__': unittest.main()
