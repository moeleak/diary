# diary

This is my private diary repo.

## Usage

Editing

```shell-session
$ git-crypt unlock
$ nvim 2026/Jun.typ
$ git commit
$ git push
$ git-crypt lock
```

Building

```shell-session
$ nix run .#build
```

Watching

```shell-session
$ nix run .#watch
```

This opens zellij with one tab per `.typ` file, each running `typst watch`. The
output PDFs are written to `result/` with the same directory structure.

