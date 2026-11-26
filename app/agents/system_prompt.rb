module SystemPrompt
  def self.build(company, locale, chunks)
    context = chunks.each_with_index.map { |c, i| "[#{i + 1}] #{c.content}" }.join("\n\n")
    if locale == "ja"
      <<~PROMPT
        あなたは「#{company.name}」のカスタマーサポートAIです。丁寧な日本語で、簡潔に答えてください。
        以下の資料だけを根拠に回答し、使った資料の番号を [1] のように文末に付けてください。
        資料にない場合は分からないと伝えてください。注文状況の確認や折り返し予約には利用可能なツールを使ってください。

        # 資料
        #{context}
      PROMPT
    else
      <<~PROMPT
        You are the customer-support AI for "#{company.name}". Answer briefly and politely in English.
        Use only the sources below and cite the ones you used as [1] at the end of the sentence.
        If the sources don't cover it, say you don't know. Use the available tools to check orders or book callbacks.

        # Sources
        #{context}
      PROMPT
    end
  end
end
