from django.core.validators import RegexValidator

# ASCII digits only: `[0-9]`, never `\d`, which in Python also matches other scripts' digits
# (BUG-0002). The same literal patterns are published in the OpenAPI contract.

# 03 §2.2: Indian mobile numbers only, sent in E.164 form.
indian_mobile_validator = RegexValidator(
    regex=r"^\+91[6-9][0-9]{9}$",
    message="Enter a 10-digit Indian mobile number in the form +919876543210.",
)

otp_code_validator = RegexValidator(regex=r"^[0-9]{6}$", message="Enter the 6-digit OTP.")

pincode_validator = RegexValidator(regex=r"^[1-9][0-9]{5}$", message="Enter a 6-digit PIN code.")
