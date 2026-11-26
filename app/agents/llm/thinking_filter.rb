# Some models (Amazon Nova) wrap reasoning in <thinking>...</thinking>. Customers must never see it, so streamed
# text passes through this filter, which also copes with tags split across chunks.
class Llm::ThinkingFilter
  OPEN = "<thinking>".freeze
  CLOSE = "</thinking>".freeze

  def initialize
    @buf = +""
    @hidden = false
  end

  def push(text)
    @buf << text
    out = +""
    loop do
      if @hidden
        i = @buf.index(CLOSE)
        unless i
          @buf = @buf.last(CLOSE.length - 1)
          break
        end
        @buf = @buf[(i + CLOSE.length)..].to_s.lstrip
        @hidden = false
      elsif (i = @buf.index(OPEN))
        out << @buf[0...i]
        @buf = @buf[(i + OPEN.length)..].to_s
        @hidden = true
      else
        keep = (1...OPEN.length).reverse_each.find { |n| @buf.length >= n && OPEN.start_with?(@buf.last(n)) } || 0
        out << @buf[0...(@buf.length - keep)]
        @buf = @buf.last(keep)
        break
      end
    end
    out
  end

  def flush
    rest = @hidden ? "" : @buf
    @buf = +""
    rest
  end
end
