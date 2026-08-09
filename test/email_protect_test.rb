# frozen_string_literal: true

require_relative "test_helper"

class EmailProtectTest < Minitest::Test
  include RenderHelpers

  def enabled_site
    site_with("protect_email" => true, "baseurl" => "/al-folio")
  end

  def disabled_site
    site_with("protect_email" => false, "baseurl" => "/al-folio")
  end

  # --- feature gate -------------------------------------------------------

  def test_disabled_by_default
    refute AlEmailProtect.enabled?(site_with({}))
  end

  def test_requires_exactly_true_not_merely_truthy
    # A site that wrote `protect_email: "false"` must not silently get the
    # feature; a non-boolean here means the config is wrong, not enabled.
    refute AlEmailProtect.enabled?(site_with("protect_email" => "true"))
    refute AlEmailProtect.enabled?(site_with("protect_email" => "false"))
  end

  def test_enabled_when_true
    assert AlEmailProtect.enabled?(enabled_site)
  end

  def test_nil_site_is_not_enabled
    refute AlEmailProtect.enabled?(nil)
  end

  # --- address splitting --------------------------------------------------

  def test_splits_on_the_last_at_sign
    # RFC 5321 allows a quoted local part to contain "@"; splitting on the first
    # one would emit a broken address.
    assert_equal ['"odd@name"', "example.com"], AlEmailProtect.split_address('"odd@name"@example.com')
  end

  def test_rejects_values_that_are_not_addresses
    assert_nil AlEmailProtect.split_address("")
    assert_nil AlEmailProtect.split_address(nil)
    assert_nil AlEmailProtect.split_address("no-at-sign")
    assert_nil AlEmailProtect.split_address("@example.com")
    assert_nil AlEmailProtect.split_address("someone@")
    assert_nil AlEmailProtect.split_address("someone@localhost")
  end

  def test_trims_surrounding_whitespace
    assert_equal %w[someone example.com], AlEmailProtect.split_address("  someone@example.com  ")
  end

  # --- text obfuscation ---------------------------------------------------

  def test_obfuscate_text_marks_every_dot
    assert_equal "someone [at] example [dot] ac [dot] uk", AlEmailProtect.obfuscate_text("someone@example.ac.uk")
  end

  def test_obfuscate_text_passes_through_non_addresses
    assert_equal "not an address", AlEmailProtect.obfuscate_text("not an address")
  end

  # --- the point of the plugin -------------------------------------------

  def test_rendered_markup_contains_no_harvestable_address
    html = render("{% al_email_protect_link 'someone@example.com' %}", site: enabled_site)

    # This is the whole reason the plugin exists: a harvester reading the HTML
    # must not find a usable address or a mailto: target.
    refute_includes html, "someone@example.com"
    refute_includes html, "mailto:"
    assert_includes html, 'data-eu="someone"'
    assert_includes html, 'data-ed="example.com"'
  end

  def test_rendered_markup_shows_readable_address_to_humans
    html = render("{% al_email_protect_link 'someone@example.com' %}", site: enabled_site)

    assert_includes html, ">someone<"
    assert_includes html, " [at] "
    assert_includes html, " [dot] "
    assert_includes html, ">example<"
    assert_includes html, ">com<"
  end

  def test_falls_back_to_mailto_when_disabled
    html = render("{% al_email_protect_link 'someone@example.com' %}", site: disabled_site)

    assert_includes html, 'href="mailto:someone@example.com"'
    refute_includes html, "al-email-protect"
  end

  def test_falls_back_to_mailto_for_unsplittable_value_even_when_enabled
    # Better to render a working (if unprotected) link than to publish a mangled
    # contact address the visitor cannot use.
    html = render("{% al_email_protect_link 'someone@localhost' %}", site: enabled_site)

    assert_includes html, 'href="mailto:someone@localhost"'
  end

  def test_renders_nothing_for_a_blank_value
    assert_equal "", render("{% al_email_protect_link '' %}", site: enabled_site)
  end

  def test_reads_the_address_from_a_liquid_variable
    html = render("{% al_email_protect_link page.email %}", site: enabled_site, assigns: { "page" => { "email" => "a@b.com" } })

    assert_includes html, 'data-eu="a"'
    assert_includes html, 'data-ed="b.com"'
  end

  def test_escapes_html_in_the_address
    html = render(%({% al_email_protect_link '<script>@example.com' %}), site: enabled_site)

    refute_includes html, "<script>"
    assert_includes html, "&lt;script&gt;"
  end

  # --- asset tags ---------------------------------------------------------

  def test_asset_tags_are_silent_when_disabled
    assert_equal "", render("{% al_email_protect_scripts %}", site: disabled_site)
    assert_equal "", render("{% al_email_protect_styles %}", site: disabled_site)
  end

  def test_asset_tags_respect_baseurl
    # Emitting a root-relative URL here is the classic al-folio 404: the demo
    # site is served from /al-folio, not /.
    assert_includes render("{% al_email_protect_scripts %}", site: enabled_site), "/al-folio/assets/al_email_protect/js/email-protect.js"
    assert_includes render("{% al_email_protect_styles %}", site: enabled_site), "/al-folio/assets/al_email_protect/css/email-protect.css"
  end

  # --- filter -------------------------------------------------------------

  def test_filter_obfuscates_when_enabled_and_passes_through_when_not
    template = "{{ 'someone@example.com' | al_email_obfuscate }}"

    assert_equal "someone [at] example [dot] com", render(template, site: enabled_site)
    assert_equal "someone@example.com", render(template, site: disabled_site)
  end

  # --- shipped assets -----------------------------------------------------

  def test_runtime_assets_exist_where_the_tags_point
    assert_path_exists ROOT.join("lib/assets/al_email_protect/js/email-protect.js")
    assert_path_exists ROOT.join("lib/assets/al_email_protect/css/email-protect.css")
  end

  def test_runtime_does_not_depend_on_jquery
    # al-folio v1 removed jQuery from the core runtime and has a regression test
    # asserting no jQuery-style errors; a plugin reintroducing "$(" would break
    # any site not loading the bootstrap-compat shim.
    # Strip line comments first: this file's own header explains why it avoids
    # jQuery, and matching that prose would fail the check it is describing.
    js = File.read(ROOT.join("lib/assets/al_email_protect/js/email-protect.js"))
      .lines.reject { |line| line.strip.start_with?("//") }.join

    refute_match(/(^|[^\w.])\$\(/, js)
    refute_includes js, "jQuery"
  end

  # --- regression: assets must land where the tags point ------------------

  def test_assets_are_published_under_slash_assets
    # Jekyll writes a StaticFile to <dest>/<dir>/<name>. Basing it on the gem
    # root instead of lib/ puts everything under /lib/assets/..., while every
    # tag emits /assets/... — a 404 that only shows up in a real build.
    entries = AlEmailProtect.asset_entries

    refute_empty entries
    entries.each do |relative_dir, name|
      assert relative_dir.start_with?("assets/al_email_protect"),
             "#{relative_dir}/#{name} would be published outside /assets/al_email_protect"
      refute_includes relative_dir, "lib/"
    end
  end

  def test_every_referenced_asset_is_actually_published
    published = AlEmailProtect.asset_entries.map { |dir, name| "/#{dir}/#{name}" }

    assert_includes published, "/assets/al_email_protect/js/email-protect.js"
  end

  # --- rewriting third-party HTML -----------------------------------------

  def test_rewrites_a_mailto_anchor_produced_by_another_gem
    # jekyll-socials emits this shape; al-folio has no hook to render just the
    # email entry differently, so the block is captured and rewritten after.
    html = %(<a href="mailto:someone@example.com" title="email"><i class="fa fa-envelope"></i></a>)
    out = render("{{ input | al_email_protect_html }}", site: enabled_site, assigns: { "input" => html })

    refute_includes out, "mailto:"
    refute_includes out, "someone@example.com"
    assert_includes out, 'data-eu="someone"'
    assert_includes out, 'data-ed="example.com"'
    # Icons and other children must survive.
    assert_includes out, "fa-envelope"
  end

  def test_decodes_percent_encoded_targets
    # jekyll-email-protect's `encode_email` percent-encodes the address, so the
    # href is escaped. Splitting without decoding yields escape sequences.
    html = %(<a href="mailto:%73%6F%6D%65@%65%78%2E%63%6F%6D">mail</a>)
    out = render("{{ input | al_email_protect_html }}", site: enabled_site, assigns: { "input" => html })

    assert_includes out, 'data-eu="some"'
    assert_includes out, 'data-ed="ex.com"'
  end

  def test_replaces_visible_address_text
    # If the label is the address itself, leaving it renders the rewrite
    # pointless — the plaintext would still be sitting in the markup.
    html = %(<a href="mailto:someone@example.com">someone@example.com</a>)
    out = render("{{ input | al_email_protect_html }}", site: enabled_site, assigns: { "input" => html })

    refute_includes out, "someone@example.com"
    assert_includes out, " [at] "
  end

  def test_leaves_non_mailto_links_untouched
    html = %(<a href="https://github.com/x">gh</a><a href="mailto:a@b.com">m</a>)
    out = render("{{ input | al_email_protect_html }}", site: enabled_site, assigns: { "input" => html })

    assert_includes out, 'href="https://github.com/x"'
    refute_includes out, "mailto:"
  end

  def test_leaves_unusable_addresses_untouched
    html = %(<a href="mailto:someone@localhost">m</a>)
    out = render("{{ input | al_email_protect_html }}", site: enabled_site, assigns: { "input" => html })

    assert_includes out, "mailto:someone@localhost"
  end

  def test_is_a_pass_through_when_disabled
    html = %(<a href="mailto:someone@example.com">m</a>)
    out = render("{{ input | al_email_protect_html }}", site: disabled_site, assigns: { "input" => html })

    assert_includes out, "mailto:someone@example.com"
  end
end
