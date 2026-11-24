"""Copy a local unsent .eml to an explicitly selected IMAP Drafts folder. Never sends mail."""
import argparse
from email import policy
from email.parser import BytesParser
import imaplib
import os
from pathlib import Path
import re
import ssl


class DraftError(RuntimeError):
    pass


def save_draft(client, folder: str, draft_key: str, payload: bytes) -> str:
    """Use serially for a given mailbox. Preserve server edits on resume."""
    if not re.fullmatch(r'[a-zA-Z0-9._-]{1,80}', draft_key):
        raise ValueError('Invalid stable draft key.')
    if not folder.isascii() or not folder or any(ord(c) < 32 or ord(c) == 127 for c in folder):
        raise ValueError('Supply the exact IMAP wire name of the Drafts folder.')
    folder_arg = '"' + folder.replace('\\', '\\\\').replace('"', '\\"') + '"'
    message = BytesParser(policy=policy.SMTP).parsebytes(payload)
    if message.get_all('X-Unsent') != ['1']:
        raise ValueError('Expected a local unsent invoice draft.')
    if message.get('X-Invoice-Draft-Key'):
        raise ValueError('Local draft already contains a resume key.')
    message['X-Invoice-Draft-Key'] = draft_key

    if client.select(folder_arg, readonly=True)[0] != 'OK':
        raise DraftError('Cannot inspect the selected Drafts folder.')

    def count():
        status, data = client.uid('SEARCH', None, 'HEADER', 'X-Invoice-Draft-Key',
                                  f'"{draft_key}"')
        if status != 'OK' or not data or not isinstance(data[0], bytes):
            raise DraftError('Could not verify draft status; do not append blindly.')
        # IMAP SEARCH HEADER is a substring match; verify the exact key.
        found = 0
        for uid in data[0].split():
            status, rows = client.uid('FETCH', uid, '(BODY.PEEK[HEADER.FIELDS (X-INVOICE-DRAFT-KEY)])')
            parts = [row[1] for row in (rows or []) if isinstance(row, tuple)]
            if status != 'OK' or len(parts) != 1:
                raise DraftError('Could not confirm the existing draft identity.')
            headers = BytesParser(policy=policy.default).parsebytes(parts[0])
            found += headers.get_all('X-Invoice-Draft-Key') == [draft_key]
        if found > 1:
            raise DraftError('More than one draft has this key; inspect the folder manually.')
        return found

    if count():
        return 'already present'
    # Never automatically repeat an APPEND with an uncertain outcome.
    if client.append(folder_arg, r'(\Draft)', None, message.as_bytes())[0] != 'OK':
        raise DraftError('APPEND not confirmed. Recheck the folder with the same key.')
    if client.select(folder_arg, readonly=True)[0] != 'OK' or not count():
        raise DraftError('APPEND accepted but not verified. Recheck with the same key.')
    return 'saved and verified'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True)
    parser.add_argument('--port', type=int, default=993)
    parser.add_argument('--folder', required=True)
    parser.add_argument('--draft-key', required=True)
    parser.add_argument('--eml', type=Path, required=True)
    args = parser.parse_args()
    try:
        # A protected runtime injects these. Never accept credentials as CLI arguments.
        user, password = os.environ['INVOICE_IMAP_USER'], os.environ['INVOICE_IMAP_PASSWORD']
        with imaplib.IMAP4_SSL(args.host, args.port, ssl_context=ssl.create_default_context(), timeout=20) as client:
            client.login(user, password)
            result = save_draft(client, args.folder, args.draft_key, args.eml.read_bytes())
        print(f'Draft {result}. No message sent.')
    except DraftError as exc:
        parser.exit(1, f'{exc} Local .eml remains available.\n')
    except (KeyError, OSError, ValueError, imaplib.IMAP4.error) as exc:
        parser.exit(1, f'Draft not confirmed ({type(exc).__name__}); keep the local .eml and check the same key before retrying.\n')


if __name__ == '__main__':
    main()
