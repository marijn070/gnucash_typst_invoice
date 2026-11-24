"""Create a local invoice email draft with a PDF; no mail service is used."""
import argparse
import os
from email.message import EmailMessage
from email.headerregistry import Address
from email.policy import SMTP
from pathlib import Path


def write_draft(pdf: Path, target: Path, *, to: str, subject: str, body: str) -> None:
    if target.suffix.lower() != '.eml':
        raise ValueError('Draft output must end in .eml.')
    data = pdf.read_bytes()
    if pdf.suffix.lower() != '.pdf' or not data.startswith(b'%PDF-'):
        raise ValueError('Expected a rendered invoice PDF.')
    address = Address(addr_spec=to)
    if not address.domain or not address.username:
        raise ValueError('Supply one complete recipient address.')
    draft = EmailMessage(policy=SMTP)
    draft['To'] = address
    draft['Subject'] = subject
    draft['X-Unsent'] = '1'
    draft.set_content(body)
    draft.add_attachment(data, maintype='application', subtype='pdf', filename=pdf.name)
    payload = draft.as_bytes()
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as file:
        file.write(payload)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pdf', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--to', required=True)
    parser.add_argument('--subject', required=True)
    parser.add_argument('--body-file', type=Path, required=True)
    args = parser.parse_args()
    try:
        write_draft(args.pdf, args.out, to=args.to, subject=args.subject,
                    body=args.body_file.read_text(encoding='utf-8'))
    except (OSError, ValueError) as exc:
        parser.exit(1, f'Could not create local draft ({type(exc).__name__}).\n')


if __name__ == '__main__':
    main()
