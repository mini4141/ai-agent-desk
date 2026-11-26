# Speech providers. "browser" (default) = no server-side audio: the client uses Web Speech / speechSynthesis.
# "aws" = Amazon Transcribe streaming + Polly neural voices with viseme speech marks.
module Speech
  Result = Struct.new(:audio_b64, :mime, :visemes, keyword_init: true)

  def self.aws? = ENV.fetch("SPEECH_PROVIDER", "browser") == "aws"

  def self.provider = @provider ||= aws? ? Speech::Polly.new : Speech::Local.new

  def self.reset! = @provider = nil

  def self.transcriber(locale, on_partial: nil, sample_rate: 16_000)
    aws? ? Speech::Transcribe.new(locale, on_partial:, sample_rate:) : Speech::MockTranscriber.new(locale)
  end
end
