"""Real Git integration: a private bare remote and two independent computers."""

from pathlib import Path
import json
import shlex
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class SyncTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles-two-computers-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.remote = self.root / "shared remote.git"
        self.git(self.root, "init", "--bare", "--initial-branch=main", str(self.remote))
        self.git(self.remote, "config", "core.hooksPath", str(self.remote / "hooks"))
        seed = self.root / "seed"
        seed.mkdir()
        self.git(seed, "init", "--initial-branch=main")
        self.configure(seed)
        for name in ["link.sh", "sync.sh"]:
            if (REPO / name).exists():
                shutil.copy2(REPO / name, seed / name)
        (seed / "vim").mkdir()
        (seed / "vim/vimrc").write_text('set number\n" original\n')
        (seed / "vscode").mkdir()
        (seed / "vscode/settings.json").write_text('{"editor.fontSize": 14}\n')
        (seed / "links.tsv").write_text(
            "vim\tvim/vimrc\t.vimrc\n"
            "vscode\tvscode/settings.json\tLibrary/Application Support/Code/User/settings.json\n"
        )
        self.git(seed, "add", ".")
        self.git(seed, "commit", "-m", "test baseline")
        self.git(seed, "remote", "add", "origin", str(self.remote))
        self.git(seed, "push", "-u", "origin", "main")
        self.a = self.root / "computer A checkout"
        self.b = self.root / "computer B checkout"
        for path in [self.a, self.b]:
            self.git(self.root, "clone", str(self.remote), str(path))
            self.configure(path)
        self.home_a = self.root / "computer A home"
        self.home_b = self.root / "computer B home"
        for checkout, home in [(self.a, self.home_a), (self.b, self.home_b)]:
            result = subprocess.run(
                ["/bin/bash", str(checkout / "link.sh"), "--home", str(home), "--apply"],
                text=True, capture_output=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def git(self, checkout, *args, check=True):
        result = subprocess.run(
            ["git", "-C", str(checkout), *args],
            text=True, capture_output=True, timeout=30,
        )
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def configure(self, checkout):
        # Test repositories must not inherit the real user's hooks or signing policy.
        self.git(checkout, "config", "user.name", "Dotfiles Test")
        self.git(checkout, "config", "user.email", "test@example.invalid")
        self.git(checkout, "config", "commit.gpgsign", "false")
        hooks = self.root / "empty test hooks"
        hooks.mkdir(exist_ok=True)
        self.git(checkout, "config", "core.hooksPath", str(hooks))

    def sync(self, checkout, action="sync"):
        home = self.home_a if checkout == self.a else self.home_b
        return subprocess.run(
            ["/bin/bash", str(checkout / "sync.sh"), action, "--home", str(home)],
            text=True, capture_output=True, timeout=30,
        )

    def success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_linked_edits_travel_from_a_to_b_and_back(self):
        (self.home_a / ".vimrc").write_text("set number\nset cursorline\n")
        self.success(self.sync(self.a))
        self.success(self.sync(self.b))
        self.assertEqual((self.home_b / ".vimrc").read_text(), "set number\nset cursorline\n")
        (self.home_b / "Library/Application Support/Code/User/settings.json").write_text('{"editor.fontSize": 18}\n')
        self.success(self.sync(self.b))
        self.success(self.sync(self.a))
        self.assertEqual(json.loads((self.home_a / "Library/Application Support/Code/User/settings.json").read_text())["editor.fontSize"], 18)
        self.assertEqual(self.git(self.a, "status", "--porcelain").stdout, "")
        self.assertEqual(self.git(self.b, "status", "--porcelain").stdout, "")

    def test_concurrent_changes_to_different_files_are_combined(self):
        (self.a / "vim/vimrc").write_text("set cursorline\n")
        (self.b / "vscode/settings.json").write_text('{"editor.fontSize": 20}\n')
        self.success(self.sync(self.a))
        self.success(self.sync(self.b))
        self.success(self.sync(self.a))
        for checkout in [self.a, self.b]:
            self.assertEqual((checkout / "vim/vimrc").read_text(), "set cursorline\n")
            self.assertEqual(json.loads((checkout / "vscode/settings.json").read_text())["editor.fontSize"], 20)

    def test_conflicting_changes_preserve_both_versions_and_stop_push(self):
        (self.a / "vim/vimrc").write_text("set number\nset shiftwidth=2\n")
        (self.b / "vim/vimrc").write_text("set number\nset shiftwidth=4\n")
        self.success(self.sync(self.a))
        published = self.git(self.remote, "rev-parse", "main").stdout
        result = self.sync(self.b)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("conflict", (result.stdout + result.stderr).lower())
        self.assertTrue((self.b / ".git/MERGE_HEAD").exists())
        conflict = (self.b / "vim/vimrc").read_text()
        self.assertIn("shiftwidth=2", conflict)
        self.assertIn("shiftwidth=4", conflict)
        self.assertEqual(self.git(self.remote, "rev-parse", "main").stdout, published)
        self.assertNotEqual(self.sync(self.b).returncode, 0)

    def test_new_managed_snippet_is_published_and_received(self):
        folder = self.a / "vscode/snippets"
        folder.mkdir()
        (folder / "new.code-snippets").write_text('{"example": {"prefix": "example", "body": "hello"}}\n')
        self.success(self.sync(self.a))
        self.success(self.sync(self.b))
        self.assertEqual((self.b / "vscode/snippets/new.code-snippets").read_bytes(), (folder / "new.code-snippets").read_bytes())

    def test_agent_instructions_are_published_and_received(self):
        instructions = "# Agent instructions\nRead README.md before changing configuration.\n"
        (self.a / "AGENTS.md").write_text(instructions)
        self.success(self.sync(self.a))
        self.success(self.sync(self.b))
        self.assertEqual((self.b / "AGENTS.md").read_text(), instructions)

    def test_existing_staged_changes_are_preserved_and_not_committed(self):
        (self.a / "vim/vimrc").write_text("set cursorline\n")
        self.git(self.a, "add", "vim/vimrc")
        before = self.git(self.a, "diff", "--cached").stdout
        head = self.git(self.a, "rev-parse", "HEAD").stdout
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("staged", result.stderr.lower())
        self.assertEqual(self.git(self.a, "diff", "--cached").stdout, before)
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD").stdout, head)

    def test_unmanaged_file_is_not_silently_committed(self):
        (self.a / "personal-notes.txt").write_text("must stay local\n")
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unmanaged", result.stderr.lower())
        self.assertEqual(self.git(self.a, "diff", "--cached", "--name-only").stdout, "")

    def test_nonempty_credential_field_blocks_without_printing_value(self):
        sentinel = "test-only-placeholder-not-a-real-credential"
        (self.a / "vscode/settings.json").write_text(json.dumps({"api_key": sentinel}))
        head = self.git(self.a, "rev-parse", "HEAD").stdout
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private", result.stderr.lower())
        self.assertNotIn(sentinel, result.stdout + result.stderr)
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD").stdout, head)
        self.assertEqual(self.git(self.a, "diff", "--cached", "--name-only").stdout, "")

    def test_normal_max_tokens_setting_is_not_treated_as_a_secret(self):
        (self.a / "vscode/settings.json").write_text('{"max_tokens": 4096}\n')
        self.success(self.sync(self.a))

    def test_missing_upstream_is_rejected_before_commit(self):
        self.git(self.a, "branch", "--unset-upstream")
        (self.a / "vim/vimrc").write_text("set cursorline\n")
        head = self.git(self.a, "rev-parse", "HEAD").stdout
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("upstream", result.stderr.lower())
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD").stdout, head)

    def test_detached_head_is_rejected(self):
        self.git(self.a, "checkout", "--detach")
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("branch", result.stderr.lower())

    def test_offline_fetch_leaves_edits_and_index_unchanged(self):
        self.git(self.a, "remote", "set-url", "origin", str(self.root / "offline.git"))
        (self.a / "vim/vimrc").write_text("set cursorline\n")
        head = self.git(self.a, "rev-parse", "HEAD").stdout
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.a / "vim/vimrc").read_text(), "set cursorline\n")
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD").stdout, head)
        self.assertEqual(self.git(self.a, "diff", "--cached", "--name-only").stdout, "")

    def test_rejected_push_keeps_a_recoverable_local_commit(self):
        hook = self.remote / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        before = self.git(self.remote, "rev-parse", "main").stdout
        (self.a / "vim/vimrc").write_text("set cursorline\n")
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git(self.remote, "rev-parse", "main").stdout, before)
        self.assertEqual(self.git(self.a, "rev-list", "--count", "origin/main..HEAD").stdout.strip(), "1")
        self.assertEqual(self.git(self.a, "status", "--porcelain").stdout, "")
        hook.unlink()
        self.success(self.sync(self.a))

    def test_status_never_commits_or_changes_the_index(self):
        (self.a / "vim/vimrc").write_text("set cursorline\n")
        head = self.git(self.a, "rev-parse", "HEAD").stdout
        result = self.sync(self.a, "status")
        self.success(result)
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD").stdout, head)
        self.assertEqual(self.git(self.a, "diff", "--cached", "--name-only").stdout, "")

    def test_detached_application_file_is_reported_instead_of_silently_ignored(self):
        target = self.home_a / ".vimrc"
        replacement = self.home_a / "replacement"
        replacement.write_text("new application configuration\n")
        replacement.replace(target)
        head = self.git(self.a, "rev-parse", "HEAD").stdout
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("link", result.stderr.lower())
        self.assertEqual(target.read_text(), "new application configuration\n")
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD").stdout, head)
        self.assertEqual(self.git(self.a, "diff", "--cached", "--name-only").stdout, "")

    def test_toml_credentials_are_not_auto_committed_or_pushed(self):
        folder = self.a / "nvim"
        folder.mkdir()
        (folder / "review.toml").write_text('api_key = "test-only-placeholder"\n')
        before = self.git(self.a, "rev-parse", "HEAD").stdout
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private", result.stderr.lower())
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD").stdout, before)
        self.assertEqual(self.git(self.a, "diff", "--cached", "--name-only").stdout, "")

    def test_current_manually_committed_credentials_are_not_pushed(self):
        (self.a / "vscode/settings.json").write_text('{"api_key": "test-only-placeholder"}\n')
        self.git(self.a, "add", "vscode/settings.json")
        self.git(self.a, "commit", "-m", "local private configuration")
        before = self.git(self.remote, "rev-parse", "main").stdout
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private", result.stderr.lower())
        self.assertEqual(self.git(self.remote, "rev-parse", "main").stdout, before)

    def test_application_detaching_a_link_during_fetch_stops_synchronization(self):
        target = self.home_a / ".vimrc"
        temporary = self.home_a / "atomic replacement"
        wrapper = self.root / "controlled-upload-pack"
        wrapper.write_text(
            "#!/bin/sh\n"
            + "printf 'new application configuration\\n' > " + shlex.quote(str(temporary)) + "\n"
            + "mv " + shlex.quote(str(temporary)) + " " + shlex.quote(str(target)) + "\n"
            + "exec " + shlex.quote(shutil.which("git-upload-pack")) + ' "$@"\n'
        )
        wrapper.chmod(0o755)
        self.git(self.a, "config", "remote.origin.uploadpack", str(wrapper))
        before = self.git(self.a, "rev-parse", "HEAD").stdout
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("link", result.stderr.lower())
        self.assertEqual(target.read_text(), "new application configuration\n")
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD").stdout, before)
        self.assertEqual(self.git(self.a, "diff", "--cached", "--name-only").stdout, "")

    def test_application_detaching_a_link_after_merge_stops_push(self):
        (self.b / "vim/vimrc").write_text("set cursorline\n")
        self.success(self.sync(self.b))
        published = self.git(self.remote, "rev-parse", "main").stdout
        target = self.home_a / ".vimrc"
        replacement = self.home_a / "atomic replacement"
        hooks = self.root / "computer A hooks"
        hooks.mkdir()
        hook = hooks / "post-merge"
        hook.write_text(
            "#!/bin/sh\n"
            + "printf 'new application configuration\\n' > " + shlex.quote(str(replacement)) + "\n"
            + "mv " + shlex.quote(str(replacement)) + " " + shlex.quote(str(target)) + "\n"
        )
        hook.chmod(0o755)
        self.git(self.a, "config", "core.hooksPath", str(hooks))
        result = self.sync(self.a)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("link", result.stderr.lower())
        self.assertEqual(target.read_text(), "new application configuration\n")
        self.assertEqual(self.git(self.remote, "rev-parse", "main").stdout, published)


if __name__ == "__main__":
    unittest.main()
