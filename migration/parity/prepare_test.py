"""python3 -I migration/parity/prepare_test.py   (needs git; not chezmoi)"""

import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import prepare  # noqa: E402

PINNED = "284637c766c3ad22391c18ea7f119cd8fd6ad8eb"
ROLES = ["gaming-desktop", "generic", "headless-agent-box", "work-laptop"]


class Profiles:
    def __init__(self, tmp):
        self.paths = []
        for role in ROLES:
            path = os.path.join(tmp, f"{role}.toml")
            with open(path, "w") as f:
                f.write(prepare.fill(os.path.join(HERE, "profiles", f"{role}.toml"),
                                     os.path.join(HERE, "profile-data.example")))
            self.paths.append(path)


class Export(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.src = os.path.join(self.tmp.name, "src")
        os.mkdir(self.src)
        self.profiles = Profiles(self.tmp.name).paths
        self.write("dot_bashrc.tmpl", "{{ .is_work }}\n")

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, text):
        path = os.path.join(self.src, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)

    def refused(self, rel, text):
        self.write(rel, text)
        return prepare.export(self.src, self.profiles)

    def test_the_pinned_commit_passes(self):
        found = subprocess.run(["git", "-C", HERE, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if found.returncode != 0:
            # As in the Nix build sandbox, where `nix flake check` runs this file.
            self.skipTest("not in a git checkout, so the pinned commit cannot be read")
        repo = found.stdout.strip()
        archive = subprocess.run(["git", "-C", repo, "archive", PINNED], capture_output=True, check=True).stdout
        pinned = os.path.join(self.tmp.name, "pinned")
        os.mkdir(pinned)
        subprocess.run(["tar", "-x", "-C", pinned], input=archive, check=True)
        os.remove(os.path.join(pinned, ".chezmoi.toml.tmpl"))
        self.assertEqual(prepare.export(pinned, self.profiles), [])

    def test_a_plain_template_passes(self):
        self.assertEqual(prepare.export(self.src, self.profiles), [])

    def test_an_empty_source_is_refused(self):
        os.remove(os.path.join(self.src, "dot_bashrc.tmpl"))
        self.assertTrue(prepare.export(self.src, self.profiles))

    def test_host_reading_functions_are_refused(self):
        for action in ('outputList "hostname"', 'expandenv "$HOME"', "now", 'output "hostname"',
                       'lookPath "jq"', 'env "HOME"', 'glob "/etc/*"', 'printf "%s" .is_work'):
            with self.subTest(action):
                self.assertTrue(self.refused("x.tmpl", "{{ " + action + " }}"))

    def test_unpinned_chezmoi_keys_are_refused_however_reached(self):
        for text in ("{{ .chezmoi.fqdnHostname }}",
                     "{{ .chezmoi.osRelease.name }}",
                     "{{ .chezmoi }}",
                     "{{ with .chezmoi }}{{ .fqdnHostname }}{{ end }}",
                     "{{ with .chezmoi.osRelease }}{{ .name }}{{ end }}",
                     '{{ dig "chezmoi" "fqdnHostname" "" . }}',
                     '{{ index . "chezmoi" "fqdnHostname" }}',
                     "{{ $d := . }}{{ $d.chezmoi.fqdnHostname }}",
                     "{{ $.chezmoi.fqdnHostname }}"):
            with self.subTest(text):
                self.assertTrue(self.refused("x.tmpl", text))

    def test_the_whole_data_map_is_refused_outside_dig(self):
        for text in ("{{ . }}", "{{ $ }}", "{{ quote . }}", "{{ $d := . }}{{ $d }}",
                     '{{ range $k, $v := . }}{{ dig $k "fqdnHostname" "" $ }}{{ end }}',
                     '{{ dig "headless" false . | quote }}{{ and (dig "a" false .) (quote .) }}'):
            with self.subTest(text):
                self.assertTrue(self.refused("x.tmpl", text))

    def test_dig_on_the_data_map_passes(self):
        text = '{{ if dig "headless" false . }}h{{ end }}{{ range (dig "overrides" (list) .) }}{{ .condition }}{{ end }}'
        self.assertEqual(self.refused("x.tmpl", text), [])

    def test_a_changed_delimiter_is_refused(self):
        self.assertTrue(self.refused("x.tmpl", "# chezmoi:template:left-delimiter=[[ right-delimiter=]]\n[[ output \"hostname\" ]]\n"))

    def test_pinned_chezmoi_keys_pass(self):
        self.assertEqual(self.refused("x.tmpl", "{{ .chezmoi.hostname }} {{ .chezmoi.osRelease.id }}"), [])

    def test_shared_templates_are_scanned(self):
        self.assertTrue(self.refused(".chezmoitemplates/part", '{{ output "hostname" }}'))

    def test_externals_are_refused(self):
        self.assertTrue(self.refused(".chezmoiexternal.toml", '[".vim"]\ntype = "archive"\n'))

    def test_include_stays_in_the_source(self):
        self.assertTrue(self.refused("x.tmpl", '{{ include "/etc/hostname" }}'))
        self.assertTrue(self.refused("x.tmpl", '{{ include "../outside" }}'))
        self.assertEqual(self.refused("x.tmpl", '{{ include "dot_bashrc.tmpl" | sha256sum }}'), [])

    def test_an_escape_cannot_spell_a_path_or_a_key(self):
        for action in ('{{ include "\\x2fetc/passwd" }}', '{{ include "\\057etc/passwd" }}',
                       '{{ include "\\x2e\\x2e/x" }}', '{{ dig "\\x63hezmoi" "kernel" . }}',
                       '{{ dig "\\u0063hezmoi" "kernel" . }}'):
            self.assertTrue(self.refused("x.tmpl", action), action)

    def test_include_takes_a_literal_only(self):
        self.assertTrue(self.refused("x.tmpl", '{{ $p := "/etc/passwd" }}{{ include $p }}'))
        self.assertTrue(self.refused("x.tmpl", '{{ range $i, $p := list "/etc/passwd" }}{{ include $p }}{{ end }}'))

    def test_an_action_it_cannot_read_is_refused(self):
        self.assertTrue(self.refused("x.tmpl", "{{ .a + .b }}"))

    def test_stat_is_answered_inside_actions_only(self):
        text = 'stat "/etc/hosts"\n{{ if stat "/usr/bin/herdr" }}y{{ end }}\n'
        self.assertEqual(self.refused("x.tmpl", text), [])
        with open(os.path.join(self.src, "x.tmpl")) as f:
            self.assertEqual(f.read(), 'stat "/etc/hosts"\n{{ if has "/usr/bin/herdr" .parity.host_paths }}y{{ end }}\n')


class Fill(unittest.TestCase):
    def run_fill(self, profile, values):
        with tempfile.TemporaryDirectory() as tmp:
            os.mkdir(os.path.join(tmp, "data"))
            for path, text in (("p.toml", profile), ("data/p.toml", values)):
                with open(os.path.join(tmp, path), "w") as f:
                    f.write(text)
            return prepare.fill(os.path.join(tmp, "p.toml"), os.path.join(tmp, "data"))

    def test_fills_placeholders(self):
        self.assertEqual(self.run_fill('[data]\nhostname = "@hostname@"\n', 'hostname = "box"\n'),
                         '[data]\nhostname = "box"\n')

    def test_a_missing_value_fails(self):
        with self.assertRaises(SystemExit):
            self.run_fill('[data]\nhostname = "@hostname@"\n', "")

    def test_a_value_with_no_placeholder_fails(self):
        with self.assertRaises(SystemExit):
            self.run_fill('[data]\nhostname = "@hostname@"\n', 'hostname = "box"\nuser = "u"\n')


if __name__ == "__main__":
    unittest.main()
