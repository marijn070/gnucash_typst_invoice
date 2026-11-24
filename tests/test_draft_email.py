import os
import subprocess
import sys
import tempfile
import unittest
from email import policy
from email.parser import BytesParser
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'invoice' / 'draft_email.py'


class DraftTest(unittest.TestCase):
    def test_local_draft_with_exact_pdf_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as base:
            root = Path(base)
            pdf = root / 'invoice.pdf'
            target = root / 'draft.eml'
            body = root / 'body.txt'
            pdf.write_bytes(b'%PDF-1.7\nfixture')
            body.write_text('Bijgaand ontvangt u uw factuur.', encoding='utf-8')
            cmd = [sys.executable, str(SCRIPT), '--pdf', str(pdf), '--out', str(target),
                   '--to', 'client@example.test', '--subject', 'Factuur 42', '--body-file', str(body)]
            subprocess.run(cmd, check=True, capture_output=True)
            original = target.read_bytes()
            msg = BytesParser(policy=policy.default).parsebytes(original)
            self.assertEqual(str(msg['To']), 'client@example.test')
            self.assertEqual(msg['X-Unsent'], '1')
            self.assertEqual(msg['Subject'], 'Factuur 42')
            self.assertEqual(msg.get_body().get_content().strip(), body.read_text())
            [attachment] = msg.iter_attachments()
            self.assertEqual(attachment.get_filename(), pdf.name)
            self.assertEqual(attachment.get_payload(decode=True), pdf.read_bytes())
            self.assertEqual(os.stat(target).st_mode & 0o777, 0o600)
            self.assertNotEqual(subprocess.run(cmd, capture_output=True).returncode, 0)
            self.assertEqual(target.read_bytes(), original)
            cmd[cmd.index('--to') + 1] = 'client@example.test\nBcc: other@example.test'
            cmd[cmd.index('--out') + 1] = str(root / 'other.eml')
            self.assertNotEqual(subprocess.run(cmd, capture_output=True).returncode, 0)
            self.assertFalse((root / 'other.eml').exists())
