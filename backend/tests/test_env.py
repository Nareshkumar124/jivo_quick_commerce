"""config.env helpers: typed env reading that never echoes values in errors."""

import pytest
from django.core.exceptions import ImproperlyConfigured

from config.env import env_bool, env_float, env_int, env_list, env_str, load_env_file

SECRET = "p@ss$word-value"


def test_env_str(monkeypatch):
    monkeypatch.setenv("JQC_T_STR", SECRET)
    assert env_str("JQC_T_STR") == SECRET
    monkeypatch.delenv("JQC_T_STR")
    assert env_str("JQC_T_STR", default="d") == "d"
    with pytest.raises(ImproperlyConfigured, match="Set the JQC_T_STR environment variable"):
        env_str("JQC_T_STR")


@pytest.mark.parametrize(
    ("raw", "expected"), [("1", True), ("TRUE", True), (" yes ", True), ("off", False)]
)
def test_env_bool(monkeypatch, raw, expected):
    monkeypatch.setenv("JQC_T_BOOL", raw)
    assert env_bool("JQC_T_BOOL") is expected


def test_env_bool_rejects_garbage_without_echoing(monkeypatch):
    monkeypatch.setenv("JQC_T_BOOL", SECRET)
    with pytest.raises(ImproperlyConfigured) as excinfo:
        env_bool("JQC_T_BOOL")
    assert SECRET not in str(excinfo.value)


def test_env_bool_default(monkeypatch):
    monkeypatch.delenv("JQC_T_BOOL", raising=False)
    assert env_bool("JQC_T_BOOL", default=True) is True


def test_env_int_and_float(monkeypatch):
    monkeypatch.setenv("JQC_T_INT", " 42 ")
    monkeypatch.setenv("JQC_T_FLOAT", "0.25")
    assert env_int("JQC_T_INT") == 42
    assert env_float("JQC_T_FLOAT") == 0.25
    monkeypatch.delenv("JQC_T_INT")
    monkeypatch.delenv("JQC_T_FLOAT")
    assert env_int("JQC_T_INT", default=7) == 7
    assert env_float("JQC_T_FLOAT", default=1.5) == 1.5


@pytest.mark.parametrize(("func", "name"), [(env_int, "integer"), (env_float, "number")])
def test_numbers_reject_garbage_without_echoing(monkeypatch, func, name):
    monkeypatch.setenv("JQC_T_NUM", SECRET)
    with pytest.raises(ImproperlyConfigured, match=name) as excinfo:
        func("JQC_T_NUM")
    assert SECRET not in str(excinfo.value)


def test_env_list(monkeypatch):
    monkeypatch.setenv("JQC_T_LIST", " a.example, ,b.example ,")
    assert env_list("JQC_T_LIST") == ["a.example", "b.example"]
    monkeypatch.delenv("JQC_T_LIST")
    assert env_list("JQC_T_LIST", default=["x"]) == ["x"]


def test_load_env_file_is_literal_and_does_not_override(monkeypatch, tmp_path):
    env_file = tmp_path / ".env"
    env_file.write_text("JQC_T_FILE_PW=ab@c$HOME:d\nJQC_T_FILE_KEEP=from-file\n")
    monkeypatch.delenv("JQC_T_FILE_PW", raising=False)
    monkeypatch.setenv("JQC_T_FILE_KEEP", "from-env")
    load_env_file(env_file)
    load_env_file(tmp_path / "missing.env")  # silently ignored
    assert env_str("JQC_T_FILE_PW") == "ab@c$HOME:d"  # no $VAR interpolation
    assert env_str("JQC_T_FILE_KEEP") == "from-env"
    monkeypatch.delenv("JQC_T_FILE_PW")


def test_env_dict(monkeypatch):
    from config.env import env_dict

    monkeypatch.setenv("JQC_T_DICT", " +919000000001:123456, ,+919000000002 : 654321 ")
    assert env_dict("JQC_T_DICT") == {"+919000000001": "123456", "+919000000002": "654321"}
    monkeypatch.delenv("JQC_T_DICT")
    assert env_dict("JQC_T_DICT", default={"a": "b"}) == {"a": "b"}
    monkeypatch.setenv("JQC_T_DICT", "no-colon")
    with pytest.raises(ImproperlyConfigured, match="key:value"):
        env_dict("JQC_T_DICT")
