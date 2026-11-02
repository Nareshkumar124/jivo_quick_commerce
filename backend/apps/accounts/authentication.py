from django.utils.translation import gettext_lazy as _
from rest_framework_simplejwt.authentication import JWTAuthentication as BaseJWTAuthentication
from rest_framework_simplejwt.exceptions import AuthenticationFailed


def user_can_authenticate(user) -> bool:
    """SIMPLE_JWT USER_AUTHENTICATION_RULE (token refresh): active and not deleted."""
    return user is not None and user.is_active and user.deleted_at is None


class JWTAuthentication(BaseJWTAuthentication):
    """simplejwt, plus: an account in its deletion grace period cannot use its access tokens
    (refresh tokens are already revoked by the deletion)."""

    def get_user(self, validated_token):
        user = super().get_user(validated_token)
        if user.deleted_at is not None:
            raise AuthenticationFailed(_("User is inactive"), code="user_inactive")
        return user


def axes_username(request, credentials) -> str | None:
    """django-axes AXES_USERNAME_CALLABLE: the admin posts `username`, and emails are matched
    case-insensitively, so lockouts count every spelling of one email together."""
    source = credentials if credentials else getattr(request, "POST", {})
    username = (source or {}).get("username")
    return username.strip().lower() if isinstance(username, str) else None
