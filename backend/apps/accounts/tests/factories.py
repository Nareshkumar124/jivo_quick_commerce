import factory

from apps.accounts.models import User


class UserFactory(factory.django.DjangoModelFactory):
    """A customer: phone only, no usable password. Pass `password="..."` to set one."""

    class Meta:
        model = User
        skip_postgeneration_save = True

    phone = factory.Sequence(lambda n: f"+9190000{n:05d}")
    name = factory.Faker("name", locale="en_IN")

    @factory.post_generation
    def password(self, create, extracted, **kwargs):
        if extracted:
            self.set_password(extracted)
        else:
            self.set_unusable_password()
        if create:
            self.save(update_fields=["password"])


class StaffUserFactory(UserFactory):
    """Staff sign in with email (sessions). Use `client.force_login()` in tests."""

    phone = None
    email = factory.Sequence(lambda n: f"staff{n}@jivo.test")
    is_staff = True


class SuperUserFactory(StaffUserFactory):
    email = factory.Sequence(lambda n: f"admin{n}@jivo.test")
    is_superuser = True
