export def get-db-file [file?: path] {
    if $file != null {
        $file
    } else if "GNC_FILE" in $env {
        $env.GNC_FILE
    } else {
        error make {msg: "No GnuCach File specified.", help: "Set $env.GNC_FILE or pas --file <path>."}
    }
}

export def get-date [] {
    if $in == null {
        null
    } else {
        $in | into datetime
    }
}
