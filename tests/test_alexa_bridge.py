"""Static contract checks for the RoomNode Assist → Alexa sample bridge.

Run: python -m unittest discover -s tests -v
Dependencies: PyYAML and Jinja2. These tests do not connect to Home Assistant.
"""

from pathlib import Path
import unittest

import jinja2
import yaml


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "homeassistant/packages/roomnode.yaml"
EXAMPLE = ROOT / "esphome/examples/voice_to_alexa.yaml"


class LambdaYamlLoader(yaml.SafeLoader):
    pass


LambdaYamlLoader.add_constructor("!lambda", lambda loader, node: loader.construct_scalar(node))


class AlexaBridgeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.package = yaml.safe_load(PACKAGE.read_text(encoding="utf-8"))
        cls.sample = yaml.load(EXAMPLE.read_text(encoding="utf-8"), Loader=LambdaYamlLoader)
        cls.script = cls.package["script"]["roomnode_speak"]
        cls.env = jinja2.Environment(autoescape=False)

    def _render_condition(self, roomnode, message, target_override=None):
        steps = self.script["sequence"]
        variables = steps[0]["variables"]
        route = variables["echo_by_roomnode"]
        context = {"roomnode": roomnode, "message": message}
        target = self.env.from_string(variables["target_speak"]).render(**context, echo_by_roomnode=route)
        if target_override is not None:
            target = target_override
        text = self.env.from_string(variables["spoken_text"]).render(**context)
        valid = self.env.from_string(steps[1]["value_template"]).render(
            target_speak=target,
            spoken_text=text,
        )
        return valid.strip().lower() == "true", target, text

    def test_alexa_action_targets_speak_entity(self):
        action = self.script["sequence"][-1]
        self.assertEqual(action["action"], "notify.send_message")
        self.assertEqual(action["target"]["entity_id"], "{{ target_speak }}")
        self.assertEqual(action["data"]["message"], "{{ spoken_text }}")

    def test_known_room_routes_to_one_echo(self):
        allowed, target, text = self._render_condition("roomnode_salon", "  Bonjour !  ")
        self.assertTrue(allowed)
        self.assertEqual(target, "notify.replace_with_your_echo_speak")
        self.assertEqual(text, "Bonjour !")

    def test_unknown_room_never_broadcasts(self):
        allowed, target, _ = self._render_condition("unregistered_node", "Bonjour")
        self.assertFalse(allowed)
        self.assertEqual(target, "")

    def test_empty_or_oversize_messages_are_rejected(self):
        for value in ("", "  ", "x" * 501):
            with self.subTest(value_length=len(value)):
                allowed, _, _ = self._render_condition("roomnode_salon", value)
                self.assertFalse(allowed)
        allowed, _, _ = self._render_condition("roomnode_salon", "x" * 500)
        self.assertTrue(allowed)

    def test_reject_non_speak_target(self):
        allowed, _, _ = self._render_condition(
            "roomnode_salon", "Bonjour", target_override="notify.all"
        )
        self.assertFalse(allowed)

    def test_esphome_hook_is_documented_and_templated(self):
        hook = self.sample["voice_assistant"]["on_tts_start"][0]["homeassistant.action"]
        self.assertEqual(hook["action"], "script.roomnode_speak")
        # The node identifier is a substitution so the same extract works for
        # every room. It must resolve to a per-device key of the HA allowlist,
        # never to a fixed value and never to a broadcast target.
        self.assertEqual(hook["data"]["roomnode"], "${node_name}")
        self.assertEqual(hook["data_template"]["message"], "{{ reply }}")
        self.assertEqual(hook["variables"]["reply"], "return x;")

    def test_esphome_hook_handles_action_errors(self):
        hook = self.sample["voice_assistant"]["on_tts_start"][0]["homeassistant.action"]
        on_error = hook.get("on_error")
        self.assertIsNotNone(on_error, "the hook must handle action failures")
        self.assertTrue(str(on_error).strip())

    def test_esphome_hook_ids_match_the_v1_firmware(self):
        # The extract must use the identifiers of the V1 firmware for the
        # Waveshare ESP32-S3-Touch-LCD-4.3C, so that it can be merged
        # under that profile's existing voice_assistant: block without
        # renaming anything.
        self.assertEqual(self.sample["voice_assistant"]["id"], "va")
        microphone = self.sample["voice_assistant"]["microphone"]
        self.assertIsInstance(
            microphone,
            list,
            "the V1 firmware declares a LIST of microphone sources",
        )
        self.assertEqual(len(microphone), 1)
        self.assertEqual(microphone[0]["microphone"], "mic_es7210")
        self.assertEqual(microphone[0]["channels"], [0])

    def test_esphome_hook_never_targets_a_broadcast(self):
        hook = self.sample["voice_assistant"]["on_tts_start"][0]["homeassistant.action"]
        payload = yaml.safe_dump(hook, allow_unicode=True)
        self.assertNotIn("notify.all", payload)
        self.assertNotIn("all.", payload)


if __name__ == "__main__":
    unittest.main()
