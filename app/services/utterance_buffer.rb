# Audio frames arrive over Action Cable on a thread pool, so they can be reordered.
# This buffer feeds the transcriber strictly in sequence-number order and waits for the tail on finish.
class UtteranceBuffer
  def initialize(locale:, sample_rate:, on_partial: nil)
    @transcriber = Speech.transcriber(locale, on_partial:, sample_rate:)
    @next = 0
    @pending = {}
    @mutex = Mutex.new
  end

  def push(seq, bytes)
    @mutex.synchronize do
      @pending[seq.to_i] = bytes
      while (chunk = @pending.delete(@next))
        @transcriber.push(chunk)
        @next += 1
      end
    end
  end

  def finish(total:, hint: nil, wait: 1.0)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait
    sleep(0.01) until @mutex.synchronize { @next >= total.to_i } || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    @transcriber.finish(hint:)
  end
end
