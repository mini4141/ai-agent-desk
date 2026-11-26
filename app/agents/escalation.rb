# Handoff triggers (SPECS F7): the customer asks for a person, or a sensitive topic.
# Low retrieval confidence is decided in AgentRun because it needs the retrieval result.
module Escalation
  HUMAN = /人と話|担当者|オペレーター|人間の|スタッフと|(talk|speak) (to|with) (a |an )?(human|person|agent|representative|operator)|real person|human agent/i
  SENSITIVE = /返金|訴訟|弁護士|個人情報の削除|refund|lawsuit|lawyer|chargeback|legal action/i

  def self.reason_for(text)
    return "customer_request" if text.match?(HUMAN)
    return "sensitive" if text.match?(SENSITIVE)

    nil
  end

  def self.handoff_message(locale)
    if locale == "ja"
      "担当者におつなぎします。少々お待ちください。これまでの内容は担当者に共有されます。"
    else
      "I'm connecting you with a human operator. Please hold on — they can see our conversation so far."
    end
  end
end
