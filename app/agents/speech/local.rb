# Offline stand-in: no server audio for web voice/avatar (browser speechSynthesis speaks the text),
# and a tone synthesiser for the phone line so the mu-law path is still exercised.
class Speech::Local
  def synthesize(_text, locale: "ja", visemes: false)
    Speech::Result.new(audio_b64: nil, mime: nil, visemes: [])
  end

  def synthesize_pcm8k(text, locale: "ja") = Mulaw.tone_pcm(text)
end
