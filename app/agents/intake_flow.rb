# Scripted 3-question intake for avatar "interview mode" (product return). Answers land on conversation.intake.
class IntakeFlow
  QUESTIONS = {
    "ja" => [["name", "まず、お名前を教えてください。"], ["product", "返品したい商品名を教えてください。"], ["reason", "返品の理由を教えてください。"]],
    "en" => [["name", "First, may I have your name?"], ["product", "Which product would you like to return?"], ["reason", "What is the reason for the return?"]]
  }.freeze
  DONE = { "ja" => "ありがとうございます。返品のご依頼を承りました。担当者から後ほどご連絡します。",
           "en" => "Thank you. Your return request has been recorded and a teammate will follow up." }.freeze

  def initialize(conversation, locale)
    @conversation = conversation
    @locale = locale == "en" ? "en" : "ja"
  end

  def opening = QUESTIONS[@locale].first.last

  # Stores the answer to the current question and returns the next prompt (or the closing line).
  def advance(answer)
    step = @conversation.intake.fetch("step", 0)
    answers = @conversation.intake.fetch("answers", {})
    answers = answers.merge(QUESTIONS[@locale][step].first => answer) if QUESTIONS[@locale][step]
    step += 1
    done = step >= QUESTIONS[@locale].size
    @conversation.update!(intake: { "step" => step, "answers" => answers, "completed" => done })
    done ? DONE[@locale] : QUESTIONS[@locale][step].last
  end
end
