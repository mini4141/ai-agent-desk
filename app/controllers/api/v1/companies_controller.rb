module Api
  module V1
    class CompaniesController < BaseController
      def show
        authorize current_user.company, :show?
        render json: current_user.company.as_api
      end

      def update
        company = current_user.company
        authorize company, :update?
        attrs = params.permit(:name, allowed_origins: [], settings: {}).to_h
        attrs["settings"] = company.settings.merge(attrs["settings"]) if attrs["settings"]
        company.update!(attrs)
        render json: company.as_api
      end
    end
  end
end
