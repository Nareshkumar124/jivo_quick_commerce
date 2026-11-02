from django.core.validators import RegexValidator

# 03 §2.2: Indian mobile numbers only, sent in E.164 form.
indian_mobile_validator = RegexValidator(
    regex=r"^\+91[6-9]\d{9}$",
    message="Enter a 10-digit Indian mobile number in the form +919876543210.",
)

otp_code_validator = RegexValidator(regex=r"^\d{6}$", message="Enter the 6-digit OTP.")

pincode_validator = RegexValidator(regex=r"^[1-9]\d{5}$", message="Enter a 6-digit PIN code.")
