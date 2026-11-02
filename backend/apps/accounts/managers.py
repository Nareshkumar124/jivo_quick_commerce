from django.contrib.auth.base_user import BaseUserManager


def normalise_email(email: str | None) -> str | None:
    """Trim and lowercase; blank becomes None (email is unique when set)."""
    if email is None:
        return None
    email = email.strip().lower()
    return email or None


def normalise_optional(value: str | None) -> str | None:
    """Trim; blank becomes None. Used for unique nullable identifiers (phone, auth_id)."""
    if value is None:
        return None
    value = value.strip()
    return value or None


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, phone: str | None, email: str | None, password: str | None, **extra):
        phone = normalise_optional(phone)
        email = normalise_email(email)
        if not phone and not email:
            raise ValueError("A user needs a phone number or an email address.")
        user = self.model(phone=phone, email=email, **extra)
        if password:
            user.set_password(password)
        else:
            # Customers and riders log in with OTP (Phase 1) and never have a password.
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_user(
        self,
        phone: str | None = None,
        email: str | None = None,
        password: str | None = None,
        **extra,
    ):
        extra.setdefault("is_staff", False)
        extra.setdefault("is_superuser", False)
        return self._create_user(phone, email, password, **extra)

    def create_superuser(self, email: str | None = None, password: str | None = None, **extra):
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        if extra["is_staff"] is not True or extra["is_superuser"] is not True:
            raise ValueError("A superuser must have is_staff=True and is_superuser=True.")
        if not normalise_email(email) or not password:
            raise ValueError("A superuser needs an email address and a password.")
        return self._create_user(extra.pop("phone", None), email, password, **extra)

    def get_by_natural_key(self, username: str | None):
        """Staff session login by email, case-insensitively (emails are stored lowercased)."""
        return self.get(**{self.model.USERNAME_FIELD: normalise_email(username)})


class CustomerManager(UserManager):
    """Customers: every non-staff user (riders are customers too until Phase 5's rider admin)."""

    def get_queryset(self):
        return super().get_queryset().filter(is_staff=False)
