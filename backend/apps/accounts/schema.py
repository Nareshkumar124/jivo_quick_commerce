"""drf-spectacular: document the project JWT authentication as the standard `jwtAuth` scheme."""

from drf_spectacular.contrib.rest_framework_simplejwt import SimpleJWTScheme


class JivoJWTScheme(SimpleJWTScheme):
    target_class = "apps.accounts.authentication.JWTAuthentication"
    name = "jwtAuth"
