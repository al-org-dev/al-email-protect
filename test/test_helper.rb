# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "al_email_protect"

ROOT = Pathname.new(File.expand_path("..", __dir__))

# Minimal stand-in for a Jekyll site. The plugin only ever reads `config`, so a
# real Jekyll::Site would add a large amount of setup for no extra coverage.
FakeSite = Struct.new(:config)

module RenderHelpers
  def render(template, site: nil, assigns: {})
    Liquid::Template.parse(template).render(assigns, registers: { site: site })
  end

  def site_with(config)
    FakeSite.new(config)
  end
end
