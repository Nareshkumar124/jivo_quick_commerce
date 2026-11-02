import logging

from apps.notifications import sms


def test_mask_phone():
    assert sms.mask_phone("+919876543210") == "+91******3210"
    assert sms.mask_phone("12345") == "*****"


def test_console_backend_masks_the_phone(settings, caplog):
    settings.SMS_BACKEND = "apps.notifications.sms.ConsoleSmsBackend"
    settings.SMS_SENDER_ID = "JIVOIN"
    with caplog.at_level(logging.WARNING, logger="apps.notifications.sms"):
        sms.send_sms("+919876543210", "123456 is your code", "1007")
    assert "+91******3210" in caplog.text
    assert "+919876543210" not in caplog.text
    assert "JIVOIN" in caplog.text


def test_locmem_backend_collects_messages():
    sms.send_sms("+919876543210", "hello", "1007")
    assert sms.outbox[-1].to == "+919876543210"
    assert sms.outbox[-1].dlt_template_id == "1007"
