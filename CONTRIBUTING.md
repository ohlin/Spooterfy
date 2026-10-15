# Contributing

Spooterfy is a personal project with one maintainer. It's built mainly for my own use, so the direction follows my taste. You're very welcome to fork it and make it your own, and contributions are welcome too.

## Before you start

- **Bugs:** open an issue with the bug report form. Small, clear fixes can go straight to a pull request.
- **New features or bigger changes:** open an issue first so we can agree it fits before you spend time on it. I may say no to things that don't match how I use the app, and that's never a judgement on the idea. A fork is a great home for it.
- **Security problems:** don't open a public issue. See [SECURITY.md](SECURITY.md).

## Making a change

1. Fork the repo and create a branch from `main`.
2. Build and run it: `./build.sh --install`, or `swift build` for a quick compile check. See the [README](README.md#building) for requirements.
3. Keep the change focused. Match the style of the surrounding code.
4. If the change affects layout, check a few window sizes. `SPOOTERFY_SNAPSHOTS=/tmp/snaps .build/debug/Spooterfy` renders the main window at several sizes.
5. Open a pull request describing what changed and why, with a screenshot for anything visual.

Pull requests are squash-merged into `main`. I review them when I can; this is a side project, so it may take a while.

## Licensing

By contributing, you agree your contribution is licensed under the project's [MIT License](LICENSE). Don't add code or assets you don't have the right to share, and don't add anything to `Resources/Fonts`.
