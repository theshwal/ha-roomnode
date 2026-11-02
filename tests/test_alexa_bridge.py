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
        allowed, target, text = self._render_condition("roomnode_test", "  Bonjour !  ")
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
                allowed, _, _ = self._render_condition("roomnode_test", value)
                self.assertFalse(allowed)
        allowed, _, _ = self._render_condition("roomnode_test", "x" * 500)
        self.assertTrue(allowed)

    def test_reject_non_speak_target(self):
        allowed, _, _ = self._render_condition(
            "roomnode_test", "Bonjour", target_override="notify.all"
        )
        self.assertFalse(allowed)

    def test_esphome_hook_is_documented_and_templated(self):
        hook = self.sample["voice_assistant"]["on_tts_start"][0]["homeassistant.action"]
        self.assertEqual(hook["action"], "script.roomnode_speak")
        self.assertEqual(hook["data"]["roomnode"], "roomnode_test")
        self.assertEqual(hook["data_template"]["message"], "{{ reply }}")
        self.assertEqual(hook["variables"]["reply"], "return x;")


if __name__ == "__main__":
    unittest.main()
