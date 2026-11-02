"""Accounts business logic. Views stay thin and call these modules:

- `otp`: OTP issue/verify, send limits, SMS dispatch
- `auth`: OTP login, token issue/revoke, logout, account deletion and anonymisation
- `profile`: profile update and push-device registration
- `addresses`: saved addresses and the default-address rules
"""
