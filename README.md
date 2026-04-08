[![macOS 10.10+](https://img.shields.io/badge/macOS-10.10+-888)](#)
[![Current release](https://img.shields.io/github/release/relikd/URL-Scheme-Defaults)](https://github.com/relikd/URL-Scheme-Defaults/releases/latest)
[![All downloads](https://img.shields.io/github/downloads/relikd/URL-Scheme-Defaults/total)](https://github.com/relikd/URL-Scheme-Defaults/releases)

<img src="media/icon.svg" width="180" height="180">


URL Scheme Defaults
===================

Simple tool to change the default macOS application for a given URL scheme (`http:`, `feed:`, etc.).
... or **disable** a URL scheme.

![screenshot](media/screenshot.png)


Installation
------------

Requires macOS Yosemite (10.10) or higher.

```sh
brew install --cask relikd/tap/url-scheme-defaults
xattr -d com.apple.quarantine "/Applications/URL Scheme Defaults.app"
```

or download from [releases](https://github.com/relikd/URL-Scheme-Defaults/releases/latest).
