# al_email_protect

Email obfuscation for [al-folio](https://github.com/alshedivat/al-folio) v1.x. Implements the plugin proposed in
[al-folio#3540](https://github.com/alshedivat/al-folio/issues/3540).

## What it does

When `protect_email` is on, addresses are **never emitted as addresses**. The HTML contains no `user@host` string and no
`mailto:` target; the two halves are carried in separate attributes and rejoined by the browser when a visitor clicks.

This is the part that matters. An implementation that ships the plaintext address and rewrites it after
`DOMContentLoaded` protects nobody — harvesters parse markup, they do not run your JavaScript. The obfuscation here
happens at build time, in Liquid.

Clicking an address copies it to the clipboard and shows a brief toast, rather than opening a mail client.

## Install

Add to your `Gemfile`:

```ruby
gem "al_email_protect", "= 1.0.0"
```

and to `_config.yml` — **both lists, or the plugin is inert**:

```yaml
plugins:
  - al_email_protect

protect_email: true # off by default
```

## Usage

The al-folio theme calls the asset tags for you. In your own layouts:

```liquid
{% al_email_protect_link site.data.socials.email %}
```

Renders a click-to-copy element when enabled, and a plain `mailto:` link when disabled — so it is safe to call
unconditionally.

For contexts that show an address as text rather than a link (a CV contact block, say):

```liquid
{{ cv.email | al_email_obfuscate }}
```

gives `someone [at] example [dot] com` when enabled, and the address unchanged when not.

## Behaviour worth knowing

- **Splits on the last `@`.** A quoted local part may legally contain one (RFC 5321).
- **Falls back rather than mangling.** A value that is not a usable address (`someone@localhost`, no dot in the domain)
  renders as an ordinary `mailto:` link. Publishing a broken contact address is worse than publishing an unprotected one.
- **Clipboard needs a secure context.** `navigator.clipboard` is undefined over plain HTTP, so the runtime falls back to
  a hidden-textarea copy, and if even that fails it shows the address so the visitor can copy it by hand.
- **Keyboard accessible.** The element is a focusable `<a>`; Enter and Space both activate it, and the toast is announced
  via `role="status"`.

## Scope

This gem owns obfuscation of addresses it is asked to render. It does not scan arbitrary page text for things that look
like addresses — that is unreliable and would corrupt legitimate content.

`al_folio_cv` renders CV contact details; wiring `al_email_obfuscate` into those layouts is a change in that gem, not
this one. See [`docs/BOUNDARIES.md`](https://github.com/alshedivat/al-folio/blob/main/docs/BOUNDARIES.md).

## Development

```bash
bundle install
bundle exec rake test
npm ci && npm run lint:prettier
```

## License

MIT
