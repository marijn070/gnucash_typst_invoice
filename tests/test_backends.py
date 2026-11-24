"""Run with: uv run --with pgserver python tests/test_backends.py [--pdf]."""
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from urllib.parse import parse_qs, urlsplit

import pgserver

ROOT = Path(__file__).resolve().parents[1]
SQL = (ROOT / 'tests/invoice_fixture.sql').read_text()


def run(*args, env, cwd=ROOT, check=True):
    return subprocess.run(args, env=env, cwd=cwd, check=check, text=True, capture_output=True)


def nu(code, env):
    return json.loads(run('nu', '--no-config-file', '-c', code + ' | to json --raw', env=env).stdout)


def main():
    # Discard inherited libpq settings: every PostgreSQL operation targets the
    # newly created private Unix socket and never the production book.
    clean = {k: v for k, v in os.environ.items() if not k.startswith(('PG', 'GNC_'))}
    with tempfile.TemporaryDirectory(prefix='nucash-test-') as path:
        tmp = Path(path)
        pg = pgserver.get_server(tmp / 'pgdata')
        try:
            uri = urlsplit(pg.get_uri())
            options = parse_qs(uri.query)
            socket_dir = Path(options['host'][0])
            assert socket_dir.is_absolute() and socket_dir.is_dir()
            psql = Path(pgserver.__file__).parent / 'pginstall/bin'
            postgres = dict(clean, PATH=f'{psql}{os.pathsep}{clean["PATH"]}', GNC_BACKEND='postgres',
                            PGHOST=str(socket_dir), PGPORT=options.get('port', ['5432'])[0],
                            PGUSER=uri.username or 'postgres', PGDATABASE=uri.path.lstrip('/') or 'postgres')
            run("psql", "-X", "-v", "ON_ERROR_STOP=1", "-c", SQL, env=postgres)
            sqlite_file = tmp / 'fixture.sqlite'
            with sqlite3.connect(sqlite_file) as db:
                db.executescript(SQL)
            sqlite_env = dict(clean, GNC_BACKEND='sqlite', GNC_FILE=str(sqlite_file))
            for command in ('nucash invoice get 101', 'nucash invoice list', 'nucash company-info',
                            'nucash account list', 'nucash transaction list --details'):
                code = f'use nucash; {command}'
                assert nu(code, postgres) == nu(code, sqlite_env), command
            invoice = nu('use nucash; nucash invoice get 101', postgres)
            assert [invoice[k] for k in ('subtotal', 'total', 'tax')] == [100, 109, 9]
            assert invoice['entries'][0]['description'] == 'Work "quoted"; test'
            assert nu(f'use nucash; nucash invoice get --file {sqlite_file} 101', postgres) == invoice
            probe = ('use nucash/utils.nu [open-db select-rows]; '
                     'select-rows (open-db) "WITH changed AS (DELETE FROM invoices RETURNING id) SELECT * FROM changed"')
            assert run('nu', '--no-config-file', '-c', probe, env=postgres, check=False).returncode != 0
            assert nu('use nucash; nucash invoice get 101', postgres) == invoice
            if '--pdf' in sys.argv:
                copy = tmp / 'render'
                copy.mkdir()
                for name in ('invoice', 'nucash'):
                    shutil.copytree(ROOT / name, copy / name, ignore=shutil.ignore_patterns('data'))
                shutil.copy(ROOT / 'justfile', copy)
                result = run('just', 'render', env=dict(postgres, GNC_INVOICE_ID='101'), cwd=copy, check=False)
                if result.returncode:
                    raise RuntimeError(result.stderr)
                pdf = copy / 'out/Factuur_Fixture_Company_101_2026-11-12.pdf'
                assert pdf.read_bytes().startswith(b'%PDF-')
        finally:
            pg.cleanup()
    print('SQLite/PostgreSQL parity and PostgreSQL read-only guard verified.' +
          (' Typst fixture PDF rendered.' if '--pdf' in sys.argv else ''))


if __name__ == '__main__':
    main()
