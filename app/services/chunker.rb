# Turns a document into retrieval chunks of "heading\nbody" (HTML sections, Markdown sections, PDF paragraphs).
module Chunker
  MAX_CHARS = 500

  Document = Struct.new(:title, :chunks, keyword_init: true)

  module_function

  def html(source)
    doc = Nokogiri::HTML(source)
    title = doc.at_css("h1")&.text&.strip.presence || doc.at_css("title")&.text&.strip
    chunks = doc.css("section").filter_map do |sec|
      heading = sec.at_css("h2, h3")&.text&.strip
      body = sec.css("p, li").map { |n| n.text.strip }.join(" ").squish
      [heading, body].compact.join("\n") if body.present?
    end
    chunks = paragraphs(doc.at_css("body")&.text.to_s) if chunks.empty?
    Document.new(title:, chunks:)
  end

  def markdown(source)
    title = source[/^#\s+(.+)$/, 1]
    chunks = source.split(/^##\s+/).drop(1).map { |s| s.strip.sub("\n", "\n") }.reject(&:blank?)
    chunks = paragraphs(source) if chunks.empty?
    Document.new(title:, chunks:)
  end

  def pdf(binary)
    text = PDF::Reader.new(StringIO.new(binary)).pages.map(&:text).join("\n\n")
    Document.new(title: text.lines.first.to_s.strip, chunks: paragraphs(text))
  end

  def paragraphs(text)
    text.split(/\n{2,}/).map(&:squish).reject(&:blank?).flat_map { |p| p.scan(/.{1,#{MAX_CHARS}}(?:\s|\z)|.{1,#{MAX_CHARS}}/m).map(&:strip) }.reject(&:blank?)
  end
end
