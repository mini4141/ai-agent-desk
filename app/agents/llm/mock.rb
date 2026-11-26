# Deterministic offline "LLM": answers from retrieved context, and calls tools when the question needs them.
class Llm::Mock
  ORDER_ID = /\b[A-Z]-\d{3,6}\b/
  PHONE = /\d{2,4}-?\d{3,4}-?\d{3,4}/
  TIME = /\b\d{1,2}:\d{2}\b/

  def stream(system:, messages:, tools:, context: [], locale: "ja")
    sleep(ms("MOCK_FIRST_TOKEN_DELAY_MS", 30))
    answer = decide(messages, tools, context, locale)
    if answer.is_a?(Hash)
      yield({ type: :tool_use, id: "tool-#{SecureRandom.hex(4)}", name: answer[:name], input: answer[:input] })
    else
      Llm.pieces(answer).each do |piece|
        yield({ type: :token, text: piece })
        sleep(ms("MOCK_TOKEN_DELAY_MS", 6))
      end
    end
  end

  private

  def ms(key, default) = ENV.fetch(key, default).to_f / 1000

  def decide(messages, tools, context, locale)
    last = messages.last
    result = last[:content].filter_map { |b| b[:tool_result] }.first
    return answer_from_tool(result, locale, context) if result

    text = last[:content].filter_map { |b| b[:text] }.join(" ")
    names = tools.map { |t| t.dig(:tool_spec, :name) }
    if names.include?("check_order_status") && (id = text[ORDER_ID])
      return { name: "check_order_status", input: { "order_id" => id } }
    end
    if names.include?("book_callback") && text.match?(/折り返し|callback|call me back/i)
      phone, time = text[PHONE], text[TIME]
      return { name: "book_callback", input: { "phone" => phone, "time" => time } } if phone && time

      return locale == "ja" ? "折り返しをご希望ですね。お電話番号と希望時間（例: 090-1234-5678 15:00）を教えてください。" : "Happy to arrange a callback. Please tell me your phone number and preferred time (e.g. 090-1234-5678 15:00)."
    end
    answer_from_context(context, locale)
  end

  def answer_from_tool(result, locale, context)
    data = result.dig(:content, 0, :json) || {}
    cite = context.empty? ? "" : " [1]"
    return (locale == "ja" ? "申し訳ありません、処理に失敗しました。担当者に確認します。" : "Sorry, that request failed. I'll check with a teammate.") if data["error"]

    if data["order_id"]
      if locale == "ja"
        "ご注文 #{data['order_id']} は現在「#{data['status']}」です。お届け予定日は#{data['eta']}です（配送業者: #{data['carrier']}）。#{cite}"
      else
        "Order #{data['order_id']} is currently “#{data['status']}”, with delivery expected on #{data['eta']} (carrier: #{data['carrier']}).#{cite}"
      end
    else
      locale == "ja" ? "折り返しを承りました。受付番号は#{data['confirmation']}、#{data['time']}頃にお電話します。" : "Your callback is booked. Confirmation #{data['confirmation']}, we'll call around #{data['time']}."
    end
  end

  def answer_from_context(context, locale)
    return(locale == "ja" ? "申し訳ありません、資料からは分かりませんでした。" : "Sorry, I couldn't find that in our documentation.") if context.empty?

    body = context.first[:text].split("\n", 2).last.to_s.strip
    sentences = body.split(/(?<=[。.!?！？])\s*/).first(2).join
    "#{sentences.truncate(220, omission: '…')} [1]"
  end
end
