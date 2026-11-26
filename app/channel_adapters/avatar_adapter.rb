# Talking avatar: same pipeline as voice, plus Polly viseme speech marks that drive the SVG mouth.
class AvatarAdapter < VoiceWebAdapter
  private

  def want_visemes? = true
end
