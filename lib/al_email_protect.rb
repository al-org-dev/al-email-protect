# frozen_string_literal: true

require "cgi"
require "jekyll"
require "liquid"
require_relative "al_email_protect/version"

# Keeps published email addresses away from harvesters.
#
# The scraper-facing half is deliberately server-side: when the feature is on,
# no `mailto:` string and no `user@host` string is present in the HTML at all.
# Address harvesters read markup, not JavaScript, so an approach that ships the
# plaintext and merely rewrites it on DOMContentLoaded protects nobody. The
# address is emitted as two halves and only rejoined in the browser.
module AlEmailProtect
  PLUGIN_ROOT = File.expand_path("..", __dir__)
  ASSETS_ROOT = File.join(PLUGIN_ROOT, "lib", "assets")

  class PluginStaticFile < Jekyll::StaticFile; end

  module_function

  def enabled?(site)
    return false unless site

    site.config["protect_email"] == true
  end

  # Splits "someone@example.ac.uk" into ["someone", "example.ac.uk"].
  #
  # Splits on the LAST "@" because the local part of an address may legally
  # contain one when quoted (RFC 5321), and getting this backwards would emit a
  # broken address rather than a protected one. Returns nil for anything not
  # usable as an address, so callers can fall back to rendering it verbatim
  # instead of silently publishing a mangled contact.
  def split_address(value)
    address = value.to_s.strip
    return nil if address.empty?

    local, _, domain = address.rpartition("@")
    return nil if local.empty? || domain.empty?
    return nil unless domain.include?(".")

    [local, domain]
  end

  # "someone [at] example [dot] com", for places that show an address as text
  # rather than as a link (CV contact blocks, for instance).
  def obfuscate_text(value)
    parts = split_address(value)
    return value.to_s unless parts

    local, domain = parts
    "#{local} [at] #{domain.gsub(".", " [dot] ")}"
  end

  def escape(value)
    CGI.escapeHTML(value.to_s)
  end

  # Builds "example [dot] com" as alternating styled spans.
  def domain_markup(domain)
    separator = %(<span class="al-email-sep"> [dot] </span>)
    domain.split(".").map { |label| %(<span class="al-email-text">#{escape(label)}</span>) }.join(separator)
  end

  # Copies the runtime into the built site. Skipped entirely when the feature is
  # off, so a site that never enables it does not carry the asset.
  class AssetsGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      return unless AlEmailProtect.enabled?(site)

      Dir.glob(File.join(ASSETS_ROOT, "**", "*")).sort.each do |source_path|
        next if File.directory?(source_path)

        relative_dir = File.dirname(source_path).sub("#{PLUGIN_ROOT}/", "")
        site.static_files << PluginStaticFile.new(site, PLUGIN_ROOT, relative_dir, File.basename(source_path))
      end
    end
  end

  class StylesTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      return "" unless AlEmailProtect.enabled?(site)

      baseurl = site.config["baseurl"] || ""
      %(<link rel="stylesheet" href="#{baseurl}/assets/al_email_protect/css/email-protect.css">\n)
    end
  end

  class ScriptsTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      return "" unless AlEmailProtect.enabled?(site)

      baseurl = site.config["baseurl"] || ""
      %(<script defer src="#{baseurl}/assets/al_email_protect/js/email-protect.js"></script>\n)
    end
  end

  # {% al_email_protect_link site.data.socials.email %}
  #
  # Emits a click-to-copy element carrying the address in halves. Falls back to
  # a plain mailto: link when the feature is off, so a layout can call this
  # unconditionally and get correct markup either way.
  class LinkTag < Liquid::Tag
    def initialize(tag_name, markup, options)
      super
      @markup = markup.strip
    end

    def render(context)
      value = context[@markup]
      value = @markup.gsub(/\A["']|["']\z/, "") if value.nil?
      return "" if value.to_s.strip.empty?

      parts = AlEmailProtect.split_address(value)
      unless AlEmailProtect.enabled?(context.registers[:site]) && parts
        escaped = AlEmailProtect.escape(value)
        return %(<a href="mailto:#{escaped}">#{escaped}</a>)
      end

      local, domain = parts
      [
        %(<a href="#" class="al-email-protect" data-eu="#{AlEmailProtect.escape(local)}" data-ed="#{AlEmailProtect.escape(domain)}">),
        %(<span class="al-email-text">#{AlEmailProtect.escape(local)}</span>),
        %(<span class="al-email-sep"> [at] </span>),
        AlEmailProtect.domain_markup(domain),
        %(</a>),
      ].join
    end
  end

  # {{ cv.email | al_email_obfuscate }}
  module Filters
    def al_email_obfuscate(value)
      return value.to_s unless AlEmailProtect.enabled?(@context.registers[:site])

      AlEmailProtect.obfuscate_text(value)
    end
  end
end

Liquid::Template.register_tag("al_email_protect_styles", AlEmailProtect::StylesTag)
Liquid::Template.register_tag("al_email_protect_scripts", AlEmailProtect::ScriptsTag)
Liquid::Template.register_tag("al_email_protect_link", AlEmailProtect::LinkTag)
Liquid::Template.register_filter(AlEmailProtect::Filters)
