from email import policy
from email.parser import BytesParser
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'invoice'))
from imap_draft import DraftError, save_draft

PAYLOAD = b'X-Unsent: 1\r\nSubject: Testfactuur\r\n\r\nConcept.\r\n'


class Mailbox:
    def __init__(self):
        self.messages = {}
        self.response_lost = False
        self.fail_search = False

    def select(self, folder, *, readonly):
        assert folder == '"INBOX.Drafts"' and readonly
        return 'OK', [b'0']

    def uid(self, command, *args):
        if command == 'SEARCH':
            if self.fail_search:
                return 'NO', [b'unavailable']
            return 'OK', [b' '.join(self.messages)]
        return 'OK', [(b'headers', self.messages[args[0]])]

    def append(self, folder, flags, date, message):
        assert folder == '"INBOX.Drafts"' and flags == r'(\Draft)'
        self.messages[str(len(self.messages) + 1).encode()] = message
        if self.response_lost:
            raise OSError('lost response')
        return 'OK', [b'appended']


class TestDraft(unittest.TestCase):
    def test_append_and_preserve_existing(self):
        mailbox = Mailbox()
        self.assertEqual(save_draft(mailbox, 'INBOX.Drafts', 'invoice-100', PAYLOAD), 'saved and verified')
        stored = mailbox.messages[b'1']
        self.assertEqual(BytesParser(policy=policy.default).parsebytes(stored)['X-Invoice-Draft-Key'], 'invoice-100')
        self.assertEqual(save_draft(mailbox, 'INBOX.Drafts', 'invoice-100', PAYLOAD.replace(b'Testfactuur', b'Edit')), 'already present')
        self.assertEqual(mailbox.messages, {b'1': stored})

    def test_resume_after_uncertain_append(self):
        mailbox = Mailbox()
        mailbox.response_lost = True
        with self.assertRaises(OSError):
            save_draft(mailbox, 'INBOX.Drafts', 'invoice-101', PAYLOAD)
        self.assertEqual(save_draft(mailbox, 'INBOX.Drafts', 'invoice-101', PAYLOAD), 'already present')
        self.assertEqual(len(mailbox.messages), 1)

    def test_fail_closed_when_lookup_fails(self):
        mailbox = Mailbox()
        mailbox.fail_search = True
        with self.assertRaises(DraftError):
            save_draft(mailbox, 'INBOX.Drafts', 'invoice-102', PAYLOAD)
        self.assertFalse(mailbox.messages)

    def test_header_substring_is_not_exact_identity(self):
        mailbox = Mailbox()
        save_draft(mailbox, 'INBOX.Drafts', 'invoice-123', PAYLOAD)
        self.assertEqual(save_draft(mailbox, 'INBOX.Drafts', 'invoice-12', PAYLOAD), 'saved and verified')
        self.assertEqual(len(mailbox.messages), 2)
