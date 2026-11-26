module Api
  module V1
    class ExperimentsController < BaseController
      def index
        authorize :metric, :index?
        percentage = Flipper[:greeting_v2].percentage_of_actors_value
        render json: { experiments: [{
          name: "greeting_v2",
          description: "Proactive greeting with suggested questions",
          enabled: Flipper[:greeting_v2].state != :off, percentage_of_actors: percentage,
          result: MetricsReport.new(from: 30.days.ago.to_date, to: Time.zone.today).call[:experiment]
        }] }
      end
    end
  end
end
