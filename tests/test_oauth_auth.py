import os
os.environ.setdefault("RUNFUEL_BASE_URL", "https://runfuel-test.example")

import asyncio
import base64
import hashlib
import json
import os
import re
import unittest
from unittest import mock
from types import SimpleNamespace
from urllib.parse import parse_qs, urlencode

from starlette.datastructures import QueryParams
from api import oauth_auth

class OAuthFlowTests(unittest.TestCase):
    def setUp(self):
        self.store = {}
        self.counters = {}
        self.original_password = os.environ.get('RUNFUEL_OAUTH_PASSWORD')
        os.environ['RUNFUEL_OAUTH_PASSWORD'] = 'unit-test-only-password'
        async def fake_redis(command):
            op = command[0].upper()
            if op == 'SET':
                self.store[command[1]] = command[2]; return 'OK'
            if op == 'GET': return self.store.get(command[1])
            if op == 'GETDEL': return self.store.pop(command[1], None)
            if op == 'DEL': return 1 if self.store.pop(command[1], None) is not None else 0
            if op == 'EVAL':
                key = command[3]; self.counters[key] = self.counters.get(key, 0) + 1; return self.counters[key]
            raise AssertionError(f'Unexpected Redis command: {op}')
        self.redis_patcher = mock.patch.object(oauth_auth, '_redis', side_effect=fake_redis)
        self.redis_patcher.start()
    def tearDown(self):
        self.redis_patcher.stop()
        if self.original_password is None: os.environ.pop('RUNFUEL_OAUTH_PASSWORD', None)
        else: os.environ['RUNFUEL_OAUTH_PASSWORD'] = self.original_password
    def test_metadata_advertises_pkce_and_dynamic_registration(self):
        response = asyncio.run(oauth_auth.metadata(None)); data = json.loads(response.body)
        self.assertEqual(response.status_code, 200); self.assertEqual(data['issuer'], oauth_auth.BASE_URL)
        self.assertIn('S256', data['code_challenge_methods_supported'])
        self.assertIn('authorization_code', data['grant_types_supported'])
    def test_registration_rejects_untrusted_redirect(self):
        request = SimpleNamespace(json=mock.AsyncMock(return_value={'redirect_uris':['https://attacker.example/callback'],'token_endpoint_auth_method':'none'}))
        response = asyncio.run(oauth_auth.register(request))
        self.assertEqual(response.status_code, 400); self.assertIn(b'invalid_client_metadata', response.body)
    def test_login_rate_limit_is_enforced(self):
        request = SimpleNamespace(headers={'x-forwarded-for':'192.0.2.123'}, body=mock.AsyncMock(return_value=urlencode({'nonce':'unused','password':'wrong-password'}).encode()))
        responses = [asyncio.run(oauth_auth.login(request)) for _ in range(oauth_auth.LOGIN_RATE_LIMIT + 1)]
        self.assertTrue(all(r.status_code == 401 for r in responses[:oauth_auth.LOGIN_RATE_LIMIT]))
        self.assertEqual(responses[-1].status_code, 429)
        self.assertEqual(responses[-1].headers['Retry-After'], str(oauth_auth.LOGIN_RATE_WINDOW))
    def test_complete_pkce_login_token_and_refresh_flow(self):
        redirect_uri = 'https://claude.ai/api/mcp/auth_callback'
        registration = SimpleNamespace(json=mock.AsyncMock(return_value={'client_name':'Claude','redirect_uris':[redirect_uri],'token_endpoint_auth_method':'none'}))
        registered = asyncio.run(oauth_auth.register(registration)); self.assertEqual(registered.status_code, 201)
        client_id = json.loads(registered.body)['client_id']; verifier = 'a' * 43
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b'=').decode()
        auth_request = SimpleNamespace(query_params=QueryParams({'client_id':client_id,'redirect_uri':redirect_uri,'response_type':'code','code_challenge':challenge,'code_challenge_method':'S256','state':'test-state','scope':'runfuel:read'}))
        authorized = asyncio.run(oauth_auth.authorize(auth_request)); self.assertEqual(authorized.status_code, 200)
        nonce = re.search(r'name="nonce" value="([^"]+)"', authorized.body.decode()).group(1)
        login_request = SimpleNamespace(headers={'x-forwarded-for':'192.0.2.10'}, body=mock.AsyncMock(return_value=urlencode({'nonce':nonce,'password':'unit-test-only-password'}).encode()))
        login = asyncio.run(oauth_auth.login(login_request)); self.assertEqual(login.status_code, 302)
        callback = parse_qs(login.headers['location'].split('?',1)[1]); self.assertEqual(callback['state'], ['test-state'])
        exchange = SimpleNamespace(body=mock.AsyncMock(return_value=urlencode({'grant_type':'authorization_code','client_id':client_id,'redirect_uri':redirect_uri,'code':callback['code'][0],'code_verifier':verifier}).encode()))
        token = asyncio.run(oauth_auth.token(exchange)); self.assertEqual(token.status_code, 200); tokens = json.loads(token.body)
        self.assertTrue(asyncio.run(oauth_auth.validate_access_token(tokens['access_token'])))
        refresh = SimpleNamespace(body=mock.AsyncMock(return_value=urlencode({'grant_type':'refresh_token','client_id':client_id,'refresh_token':tokens['refresh_token']}).encode()))
        refreshed = asyncio.run(oauth_auth.token(refresh)); self.assertEqual(refreshed.status_code, 200); new_tokens = json.loads(refreshed.body)
        self.assertNotEqual(tokens['refresh_token'], new_tokens['refresh_token'])
        replay = SimpleNamespace(body=mock.AsyncMock(return_value=urlencode({'grant_type':'refresh_token','client_id':client_id,'refresh_token':tokens['refresh_token']}).encode()))
        replay_response = asyncio.run(oauth_auth.token(replay)); self.assertEqual(replay_response.status_code, 400)
        self.assertIn(b'invalid_grant', replay_response.body)
    def test_login_rejects_wrong_password(self):
        request = SimpleNamespace(headers={'x-forwarded-for':'192.0.2.55'}, body=mock.AsyncMock(return_value=urlencode({'nonce':'unused','password':'wrong-password'}).encode()))
        response = asyncio.run(oauth_auth.login(request)); self.assertEqual(response.status_code, 401)

if __name__ == '__main__': unittest.main()
