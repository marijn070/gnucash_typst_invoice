# An explicit SQLite path always takes precedence over the configured backend.
export def open-db [file?: path] {
    if $file != null {
        {backend: sqlite, handle: (open $file)}
    } else if ($env.GNC_BACKEND? | default "sqlite") == "postgres" {
        if ([($env.PGHOST? | default ""), ($env.PGDATABASE? | default ""), ($env.PGUSER? | default "")] | any {|value| $value == "" }) {
            error make {msg: "Set PGHOST, PGDATABASE and PGUSER for the PostgreSQL backend."}
        }
        {backend: postgres}
    } else if ($env.GNC_BACKEND? | default "sqlite") != "sqlite" {
        error make {msg: "GNC_BACKEND must be sqlite or postgres."}
    } else if "GNC_FILE" in $env {
        {backend: sqlite, handle: (open $env.GNC_FILE)}
    } else {
        error make {msg: "No GnuCash file specified.", help: "Set GNC_FILE or pass --file."}
    }
}

# Only use this helper with repository-owned, static SELECT statements.
export def select-rows [db, sql: string] {
    if $db.backend == "sqlite" {
        $db.handle | query db $sql
    } else {
        let select = $sql | str trim | str trim --right --char ';'
        let query = "BEGIN READ ONLY; SET LOCAL statement_timeout = '30s'; SELECT COALESCE(json_agg(row_to_json(rows)), '[]'::json) FROM (" + $select + ') AS rows; ROLLBACK;'
        let result = $query | ^psql -X -w -qAt -v ON_ERROR_STOP=1 | complete
        if $result.exit_code != 0 {
            # Do not echo connection or SQL diagnostics containing book details.
            error make {msg: "PostgreSQL query failed. Check connection settings and GnuCash schema compatibility."}
        }
        $result.stdout | from json
    }
}

export def get-date [] {
    if $in == null {
        null
    } else {
        $in | into datetime
    }
}
