# Amazon Transcribe streaming for one utterance. Audio chunks are pushed as they arrive;
# partial results are reported through on_partial; finish returns the final transcript.
class Speech::Transcribe
  LANGUAGE = { "ja" => "ja-JP", "en" => "en-US" }.freeze

  def initialize(locale, on_partial: nil, sample_rate: 16_000)
    @locale = locale
    @on_partial = on_partial
    @sample_rate = sample_rate
    @finals = []
    @last_partial = ""
    @started = false
  end

  def push(chunk)
    start unless @started
    @input.signal_audio_event_event(audio_chunk: chunk)
  end

  def finish(hint: nil)
    return @finals.join(" ").strip unless @started

    @input.signal_end_stream
    @response.join!
    sleep(0.2) # let the event-stream thread deliver the last transcript event
    transcript
  end

  private

  # Final segments, plus a trailing partial if the stream closed before Transcribe finalised it.
  def transcript = [*@finals, @last_partial].reject(&:empty?).join(" ").strip

  def start
    @started = true
    client = Aws::TranscribeStreamingService::AsyncClient.new(region: ENV.fetch("AWS_REGION", "ap-southeast-2"))
    @input = Aws::TranscribeStreamingService::EventStreams::AudioStream.new
    output = Aws::TranscribeStreamingService::EventStreams::TranscriptResultStream.new
    output.on_transcript_event_event do |event|
      event.transcript.results.each do |result|
        text = result.alternatives.first&.transcript.to_s
        if result.is_partial
          @last_partial = text
          @on_partial&.call(text)
        else
          @finals << text
          @last_partial = ""
        end
      end
    end
    @response = client.start_stream_transcription(
      language_code: LANGUAGE.fetch(@locale, "en-US"), media_encoding: "pcm", media_sample_rate_hertz: @sample_rate,
      input_event_stream_handler: @input, output_event_stream_handler: output
    )
  end
end
