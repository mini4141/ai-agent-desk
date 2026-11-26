module Api
  module V1
    class ToolsController < BaseController
      def index
        authorize Tool
        render json: { tools: policy_scope(Tool).order(:id).map(&:as_api) }
      end

      def create
        authorize Tool
        tool = Tool.create!(params.permit(:name, :description, :endpoint, :encrypted_secret).merge(params_schema: params[:params_schema]&.to_unsafe_h || {}))
        render json: tool.as_api, status: :created
      end

      # Console "test call": runs the tool against the company's endpoint with the supplied sample input.
      def test
        tool = Tool.find(params[:id])
        authorize tool, :test?
        output = ToolInvoker.new.call(tool, params[:input]&.to_unsafe_h || {})
        render json: { tool: tool.name, output: output }
      end
    end
  end
end
