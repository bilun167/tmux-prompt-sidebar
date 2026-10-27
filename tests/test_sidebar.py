import importlib.machinery
import importlib.util
import os
import unittest

BIN = os.path.join(os.path.dirname(__file__), "..", "bin")


def load(name):
    loader = importlib.machinery.SourceFileLoader(name.replace("-", "_"), os.path.join(BIN, name))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
    loader.exec_module(module)
    return module


sidebar = load("tmux-sidebar")
hook = load("tmux-claude-hook")


def pane(**kw):
    p = {f: "" for f in sidebar.FIELDS}
    p.update(session_name="main", window_index="1", window_id="@1", window_name="zsh",
             pane_id="%1", pane_current_command="claude", pane_current_path="/tmp")
    p.update(kw)
    return p


def bar():
    s = sidebar.Sidebar.__new__(sidebar.Sidebar)  # no tmux needed
    s.host = "box.local"
    return s


class Text(unittest.TestCase):
    def test_fit_pads_and_clips_to_width(self):
        self.assertEqual(sidebar.fit("abc", 5), "abc  ")
        self.assertEqual(sidebar.fit("abcdef", 5), "abcd…")
        self.assertEqual(sidebar.width(sidebar.fit("日本語テキスト", 7)), 7)

    def test_topic_drops_spinner_and_host(self):
        self.assertEqual(sidebar.topic("✳ Fix the build", "box.local"), "Fix the build")
        self.assertEqual(sidebar.topic("box", "box.local"), "")
        self.assertEqual(sidebar.topic("box.local: ~", "box.local"), "")

    def test_hook_first_line_and_clip(self):
        self.assertEqual(hook.first_line("\n\n  fix   the\tbuild \nmore"), "fix the build")
        self.assertEqual(hook.clip("abcdef", 4), "abc…")
        self.assertEqual(hook.clip("abc", 4), "abc")


class Label(unittest.TestCase):
    def test_prompt_with_title_and_marks(self):
        p = pane(**{"@claude_prompt": "fix it", "pane_title": "✳ Build fix", "@claude_state": "waiting"})
        self.assertEqual(bar().label(p, True), ("fix it", "Build fix", "?"))
        p.update({"@claude_state": "done", "@claude_unread": "1"})
        self.assertEqual(bar().label(p, True)[2], "●")

    def test_spinner_in_title_means_working(self):
        p = pane(pane_title="⠂ Thinking")
        self.assertEqual(bar().label(p, True), ("Thinking", "", "⋯"))

    def test_shell_shows_folder(self):
        p = pane(pane_current_command="-zsh", pane_current_path="/home/u/proj", **{"@claude_prompt": "old"})
        self.assertEqual(bar().label(p, True), ("proj", "", " "))

    def test_fallback_strips_mac_zsh_window_name(self):
        p = pane(window_name="u@box: vim", pane_current_command="vim")
        self.assertEqual(bar().label(p, True)[0], "vim")


class Age(unittest.TestCase):
    def test_format(self):
        self.assertEqual([sidebar.age(n) for n in (0, 59, 60, 3599, 3600, 86399, 86400 * 3)],
                         ["0s", "59s", "1m", "59m", "1h", "23h", "3d"])

    def test_on_the_first_row_right_aligned(self):
        p = pane(**{"@claude_prompt": "fix the flaky login test in CI", "@claude_state": "waiting",
                    "@claude_since": "1000"})
        rows = bar().build("@9", [[p]], 30, now=1000 + 720)
        self.assertEqual([r[0] for r in rows], ["▾ main".ljust(30), "  1 ? fix the flaky login  12m",
                                                "  ⋮   test in CI".ljust(30)])

    def test_dropped_when_narrow_unknown_or_off(self):
        p = pane(**{"@claude_prompt": "fix it", "@claude_state": "done", "@claude_since": "1000"})
        self.assertNotIn("1h", bar().build("@9", [[p]], 18, now=5000)[1][0])
        self.assertIn("1h", bar().build("@9", [[p]], 22, now=5000)[1][0])
        p["@claude_since"] = ""
        self.assertEqual(bar().build("@9", [[p]], 22, now=5000)[1][0].rstrip(), "  1 · fix it")
        p["@claude_since"] = "1000"
        b = bar()
        b.ages = False
        self.assertEqual(b.build("@9", [[p]], 22, now=5000)[1][0].rstrip(), "  1 · fix it")

    def test_not_for_a_shell_or_a_spinner_the_hook_did_not_report(self):
        shell = pane(pane_current_command="zsh", **{"@claude_state": "done", "@claude_since": "1000"})
        spin = pane(pane_title="⠂ Thinking", **{"@claude_state": "done", "@claude_since": "1000"})
        self.assertEqual(bar().since(shell, 5000), "")
        self.assertEqual(bar().since(spin, 5000), "")


class Build(unittest.TestCase):
    def test_split_window_rows(self):
        a = pane(pane_id="%1", pane_active="1", **{"@claude_prompt": "first"})
        b = pane(pane_id="%2", **{"@claude_prompt": "second"})
        other = pane(window_index="2", window_id="@2", pane_id="%3", **{"@claude_unread": "1"})
        rows = bar().build("@1", [[a, b], [other]], 30)
        self.assertEqual([r[0].rstrip() for r in rows], ["▾ main", "  1 · first", "  ⋮ · second", "  2 ● zsh"])
        self.assertEqual([r[1] for r in rows], ["bold", "current", "bold", "unread"])
        self.assertTrue(all(len(r[0]) == 30 for r in rows))


if __name__ == "__main__":
    unittest.main()
