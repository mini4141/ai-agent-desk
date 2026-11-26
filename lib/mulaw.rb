# G.711 mu-law codec (8 kHz telephony audio) and a tiny tone synthesiser used by the offline phone stand-in.
module Mulaw
  BIAS = 0x84
  CLIP = 32_635

  module_function

  # pcm: String of 16-bit little-endian mono samples -> Array of mu-law bytes
  def encode(pcm)
    pcm.unpack("s<*").map { |s| encode_sample(s) }
  end

  # ulaw: String (or byte Array) -> String of 16-bit little-endian PCM
  def decode(ulaw)
    bytes = ulaw.is_a?(String) ? ulaw.bytes : ulaw
    bytes.map { |u| decode_sample(u) }.pack("s<*")
  end

  def encode_sample(sample)
    sign = sample.negative? ? 0x80 : 0
    s = [sample.abs, CLIP].min + BIAS
    exponent = 7
    mask = 0x4000
    while exponent.positive? && (s & mask).zero?
      exponent -= 1
      mask >>= 1
    end
    mantissa = (s >> (exponent + 3)) & 0x0F
    ~(sign | (exponent << 4) | mantissa) & 0xFF
  end

  def decode_sample(byte)
    u = ~byte & 0xFF
    sample = (((u & 0x0F) << 3) + BIAS) << ((u >> 4) & 0x07)
    sample -= BIAS
    (u & 0x80).zero? ? sample : -sample
  end

  # Speech-like babble: one short tone per character, pitch derived from the character.
  def tone_pcm(text, rate: 8000)
    samples = text.each_char.flat_map do |ch|
      freq = 180 + (ch.ord % 9) * 55
      Array.new((rate * 0.06).to_i) { |i| (Math.sin(2 * Math::PI * freq * i / rate) * 6000 * Math.sin(Math::PI * i / (rate * 0.06))).to_i }
    end
    samples.first(rate * 6).pack("s<*")
  end
end
