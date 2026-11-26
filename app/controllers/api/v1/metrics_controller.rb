module Api
  module V1
    class MetricsController < BaseController
      def index
        authorize :metric, :index?
        from = params[:from].presence&.to_date || 30.days.ago.to_date
        to = params[:to].presence&.to_date || Time.zone.today
        render json: MetricsReport.new(from:, to:, channel: params[:channel].presence, variant: params[:variant].presence).call
      end

      def latency
        authorize :metric, :index?
        render json: LatencyReport.new(days: (params[:days] || 7).to_i).call
      end

      def rollup
        authorize :metric, :rollup?
        MetricsRollupJob.new.perform((params[:days] || 30).to_i, current_user.company_id)
        render json: { status: "done" }
      end
    end
  end
end
