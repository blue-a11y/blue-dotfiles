"""Narrow check for VSCodeVim's executable-path validation before shell execution."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class PortabilityTest(unittest.TestCase):
    def test_input_method_helper_supports_a_machine_local_binary(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-input-method-") as folder:
            binary = Path(folder) / "macism test binary"
            binary.write_text('#!/bin/sh\nif [ "$#" -eq 0 ]; then printf "test.current.input.method\\n"; else printf "%s\\n" "$1"; fi\n')
            binary.chmod(0o755)
            environment = os.environ.copy()
            environment["DOTFILES_MACISM_BIN"] = str(binary)
            # Guard the real input-method boundary: never invoke the actual macism
            # while testing the previous implementation's hard-coded executable.
            guard = 'exec() { [ "$1" = "$DOTFILES_MACISM_BIN" ] || return 127; builtin exec "$@"; }; source "$1" "${@:2}"'
            for args, expected in [([], "com.apple.keylayout.ABC"), (["--current"], "test.current.input.method")]:
                with self.subTest(args=args):
                    result = subprocess.run(
                        ["/bin/bash", "-c", guard, "test-helper", str(REPO / "vscode/bin/vim-im-force-abc"), *args],
                        env=environment, text=True, capture_output=True, timeout=10,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), expected)


if __name__ == "__main__":
    unittest.main()
