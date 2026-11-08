import json

import pytest

import razer_ctl


class FakeDevice:
    name = "Razer Test Mouse"
    serial = "ABC123"
    type = "mouse"
    battery_level = 87
    is_charging = False
    dpi = (1600, 1600)
    max_dpi = 30000
    poll_rate = 1000
    brightness = 55.0

    def __init__(self, caps=None):
        self._caps = caps if caps is not None else {"battery", "dpi", "poll_rate", "brightness"}

    def has(self, cap):
        return cap in self._caps


class FakeManager:
    def __init__(self, devices):
        self.devices = devices


def test_status_reports_all_fields():
    out = razer_ctl.status(FakeManager([FakeDevice()]))
    assert out == {
        "connected": True,
        "name": "Razer Test Mouse",
        "serial": "ABC123",
        "battery": 87,
        "charging": False,
        "dpi": 1600,
        "maxDpi": 30000,
        "pollRate": 1000,
        "brightness": 55,
    }


def test_status_no_devices():
    assert razer_ctl.status(FakeManager([])) == {"connected": False}


def test_status_skips_missing_capabilities():
    out = razer_ctl.status(FakeManager([FakeDevice(caps={"dpi"})]))
    assert out["dpi"] == 1600
    assert "battery" not in out and "brightness" not in out and "pollRate" not in out


def test_set_dpi_sets_both_axes():
    dev = FakeDevice()
    razer_ctl.apply(FakeManager([dev]), "dpi", "3200")
    assert dev.dpi == (3200, 3200)


def test_set_dpi_clamps_to_max():
    dev = FakeDevice()
    razer_ctl.apply(FakeManager([dev]), "dpi", "999999")
    assert dev.dpi == (30000, 30000)


def test_set_brightness_clamps_0_100():
    dev = FakeDevice()
    razer_ctl.apply(FakeManager([dev]), "brightness", "150")
    assert dev.brightness == 100
    razer_ctl.apply(FakeManager([dev]), "brightness", "-5")
    assert dev.brightness == 0


def test_poll_rate_is_read_only():
    with pytest.raises(ValueError):
        razer_ctl.apply(FakeManager([FakeDevice()]), "pollrate", "500")


def test_unknown_setting_rejected():
    with pytest.raises(ValueError):
        razer_ctl.apply(FakeManager([FakeDevice()]), "bogus", "1")


def test_main_status_prints_json(capsys):
    rc = razer_ctl.main(["status"], manager=FakeManager([FakeDevice()]))
    assert rc == 0
    assert json.loads(capsys.readouterr().out)["battery"] == 87


def test_main_without_daemon_prints_disconnected(capsys):
    def boom():
        raise RuntimeError("no daemon")

    rc = razer_ctl.main(["status"], manager_factory=boom)
    assert rc == 0
    assert json.loads(capsys.readouterr().out) == {"connected": False}
