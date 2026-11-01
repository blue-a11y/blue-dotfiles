"""Exercise the real linker against disposable homes, including paths with spaces."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class LinkTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="blue-dotfiles-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repository with spaces"
        self.repo.mkdir()
        for name in ["ghostty", "vscode", "zed", "nvim", "vim", "kero"]:
            shutil.copytree(REPO / name, self.repo / name)
        shutil.copy2(REPO / "links.tsv", self.repo / "links.tsv")
        if (REPO / "link.sh").exists():
            shutil.copy2(REPO / "link.sh", self.repo / "link.sh")
        self.home = self.root / "home with spaces"

    def run_link(self, *args):
        return subprocess.run(
            ["/bin/bash", str(self.repo / "link.sh"), "--home", str(self.home), *args],
            text=True, capture_output=True, timeout=15,
        )

    def check_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def backup_sessions(self):
        root = self.home / ".local/state/blue-dotfiles/backups"
        return sorted(root.iterdir()) if root.exists() else []

    def test_default_is_preview_and_does_not_create_home(self):
        result = self.run_link()
        self.check_success(result)
        self.assertIn("[preview]", result.stdout)
        self.assertFalse(self.home.exists())

    def test_apply_links_all_selected_files_including_paths_with_spaces(self):
        self.check_success(self.run_link("--apply"))
        for line in (self.repo / "links.tsv").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            _, source, relative = line.split("\t")
            target = self.home / relative
            self.assertTrue(target.is_symlink(), relative)
            self.assertEqual(target.resolve(), (self.repo / source).resolve())
        self.assertFalse((self.home / ".vscode/argv.json").exists())

    def test_apply_preserves_regular_files_directories_and_dangling_links(self):
        ghostty = self.home / ".config/ghostty/config"
        ghostty.parent.mkdir(parents=True)
        ghostty.write_text("old ghostty\n")
        snippets = self.home / "Library/Application Support/Code/User/snippets"
        snippets.mkdir(parents=True)
        (snippets / "keep.json").write_text('{"keep": true}\n')
        nvim = self.home / ".config/nvim"
        nvim.symlink_to("missing-old-configuration")

        self.check_success(self.run_link("--apply", "ghostty", "vscode", "nvim"))
        backups = self.backup_sessions()
        self.assertEqual(len(backups), 1)
        backup = backups[0]
        self.assertEqual((backup / ".config/ghostty/config").read_text(), "old ghostty\n")
        self.assertEqual((backup / "Library/Application Support/Code/User/snippets/keep.json").read_text(), '{"keep": true}\n')
        self.assertTrue((backup / ".config/nvim").is_symlink())
        self.assertEqual(os.readlink(backup / ".config/nvim"), "missing-old-configuration")

    def test_repeated_apply_is_idempotent_and_keeps_original_backup(self):
        self.home.mkdir()
        (self.home / ".vimrc").write_text("original vim\n")
        self.check_success(self.run_link("--apply", "vim"))
        first = self.backup_sessions()
        self.check_success(self.run_link("--apply", "vim"))
        self.assertEqual(self.backup_sessions(), first)
        self.assertEqual((first[0] / ".vimrc").read_text(), "original vim\n")

    def test_unknown_selection_fails_before_creating_any_files(self):
        result = self.run_link("--apply", "unknown-editor")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown application", result.stderr)
        self.assertFalse(self.home.exists())

    def test_missing_source_fails_before_modifying_any_target(self):
        target = self.home / ".config/ghostty/config"
        target.parent.mkdir(parents=True)
        target.write_text("must remain unchanged\n")
        (self.repo / "vscode/settings.json").unlink()
        result = self.run_link("--apply", "ghostty", "vscode")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing source", result.stderr)
        self.assertFalse(target.is_symlink())
        self.assertEqual(target.read_text(), "must remain unchanged\n")
        self.assertFalse((self.home / ".local").exists())

    def test_selecting_one_application_leaves_other_applications_alone(self):
        self.check_success(self.run_link("--apply", "neovim"))
        self.assertTrue((self.home / ".config/nvim").is_symlink())
        self.assertFalse((self.home / ".vimrc").exists())
        self.assertFalse((self.home / "Library").exists())

    def test_existing_parent_link_to_source_is_skipped_without_moving_source(self):
        parent = self.home / ".config/ghostty"
        parent.parent.mkdir(parents=True)
        parent.symlink_to(self.repo / "ghostty", target_is_directory=True)
        source = self.repo / "ghostty/config"
        original = source.read_bytes()
        self.check_success(self.run_link("--apply", "ghostty"))
        self.assertFalse(source.is_symlink(), "The source must never become a self-link")
        self.assertEqual(source.read_bytes(), original)
        self.assertEqual(self.backup_sessions(), [])

    def test_existing_hardlink_is_backed_up_and_replaced_with_a_symlink(self):
        self.home.mkdir()
        target = self.home / ".vimrc"
        source = self.repo / "vim/vimrc"
        original = source.read_bytes()
        os.link(source, target)
        self.check_success(self.run_link("--apply", "vim"))
        self.assertTrue(target.is_symlink())
        self.assertEqual(target.resolve(), source.resolve())
        self.assertEqual((self.backup_sessions()[0] / ".vimrc").read_bytes(), original)
        replacement = source.with_name("replacement")
        replacement.write_text("set cursorline\n")
        replacement.replace(source)
        self.assertEqual(target.read_text(), "set cursorline\n")

    def test_wrong_parent_link_into_repository_is_rejected_before_mutation(self):
        parent = self.home / ".config/ghostty"
        parent.parent.mkdir(parents=True)
        parent.symlink_to(self.repo / "vim", target_is_directory=True)
        unrelated = self.repo / "vim/config"
        unrelated.write_text("unrelated repository file\n")
        result = self.run_link("--apply", "ghostty")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(unrelated.is_symlink())
        self.assertEqual(unrelated.read_text(), "unrelated repository file\n")
        self.assertEqual(self.backup_sessions(), [])

    def test_root_path_variants_are_rejected_even_in_preview(self):
        # Preview only: this test must never attempt a write under the filesystem root.
        for target in ["/", "////", "/tmp/.."]:
            with self.subTest(target=target):
                result = self.run_link("--home", target, "vim")
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
