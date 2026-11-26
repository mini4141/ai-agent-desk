# Buffers streamed tokens and releases complete sentences so TTS can start on the first one.
class SentenceSplitter
  TERMINATORS = /(?<=[。！？!?\n])|(?<=[.])(?=\s)/

  def initialize = @buffer = +""

  def push(text)
    @buffer << text
    parts = @buffer.split(TERMINATORS)
    return [] if parts.empty?

    @buffer = ends_with_terminator?(@buffer) ? +"" : parts.pop.to_s.dup
    parts.map(&:strip).reject(&:empty?)
  end

  def flush
    rest = @buffer.strip
    @buffer = +""
    rest.empty? ? [] : [rest]
  end

  private

  def ends_with_terminator?(s) = s.match?(/[。！？!?\n]\z/) || s.match?(/\.\s\z/)
end
