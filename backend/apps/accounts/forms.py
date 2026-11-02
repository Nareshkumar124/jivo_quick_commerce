from django import forms
from unfold.forms import UserChangeForm as UnfoldUserChangeForm
from unfold.forms import UserCreationForm as UnfoldUserCreationForm

from apps.accounts.models import User


class UserCreationForm(UnfoldUserCreationForm):
    class Meta:
        model = User
        fields = ("email", "phone", "name")

    def clean(self):
        cleaned = super().clean()
        if not cleaned.get("email") and not cleaned.get("phone"):
            raise forms.ValidationError("Enter an email address or a phone number.")
        return cleaned


class UserChangeForm(UnfoldUserChangeForm):
    class Meta:
        model = User
        fields = "__all__"
