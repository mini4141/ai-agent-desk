class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError do
    render json: { error: "forbidden" }, status: :forbidden
  end
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not_found" }, status: :not_found
  end
  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: "bad_request", message: e.message }, status: :bad_request
  end
end
