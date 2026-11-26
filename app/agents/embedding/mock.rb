require "zlib"

# Deterministic offline embedding: hashed word / CJK-bigram bag, L2-normalised to 1024 dims.
# Similar text shares n-grams, so cosine search behaves sensibly without calling Bedrock.
class Embedding::Mock
  PARTICLES = /[はがのをにでともやへ]/
  FILLER = /教えて|ください|方法|について|でしょうか|ですか|ますか|したい|どれくらい|です|ます/
  CJK_RUN = /[\p{Hiragana}\p{Katakana}\p{Han}ー]+/

  def embed(text)
    vec = Array.new(Embedding::DIMENSIONS, 0.0)
    features(text.to_s.downcase).each do |f|
      h = Zlib.crc32(f)
      vec[h % Embedding::DIMENSIONS] += (h >> 20).odd? ? -1.0 : 1.0
    end
    norm = Math.sqrt(vec.sum { |v| v * v })
    norm.zero? ? vec : vec.map { |v| v / norm }
  end

  private

  def features(text)
    words = text.scan(/[a-z0-9][a-z0-9-]*/)
    cjk = text.gsub(FILLER, " ").scan(CJK_RUN).flat_map do |run|
      run = run.gsub(PARTICLES, "")
      run.length < 2 ? [run] : run.chars.each_cons(2).map(&:join)
    end
    words + cjk
  end
end
