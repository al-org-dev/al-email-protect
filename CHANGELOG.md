# Changelog

## Unreleased

- Initial release of `al_email_protect`, implementing the email obfuscation proposed in
  [alshedivat/al-folio#3540](https://github.com/alshedivat/al-folio/issues/3540) (source PR
  [#3532](https://github.com/alshedivat/al-folio/pull/3532)).
- Addresses are split server-side and never appear as `user@host` or `mailto:` in the built HTML.
- `{% al_email_protect_link %}` tag, `al_email_obfuscate` filter, and `_styles` / `_scripts` asset tags.
- Vanilla-JS runtime (no jQuery), with a clipboard fallback for non-secure contexts and keyboard activation.
