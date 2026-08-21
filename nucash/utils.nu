export def open-db [file?: path] {
    let file = if $file != null {
        $file
    } else if "GNC_FILE" in $env {
        $env.GNC_FILE
    } else {
        error make {msg: "No GnuCach File specified.", help: "Set $env.GNC_FILE or pas --file <path>."}
    }
    open $file
}

export def get-date [] {
    if $in == null {
        null
    } else {
        $in | into datetime
    }
}
