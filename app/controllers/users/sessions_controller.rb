# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    # Generate token and include it in metadata if needed, but devise-jwt automatically inserts it into the Authorization header.
    # We just return the user json.
    render json: {
      status: { code: 200, message: "Logged in successfully." },
      data: UserBlueprint.render_as_hash(resource)
    }, status: :ok
  end

  def respond_to_on_destroy
    # Check if authorization header is present
    if request.headers["Authorization"].present?
      begin
        jwt_payload = JWT.decode(
          request.headers["Authorization"].split(" ").last,
          Devise.jwt_secret || "default_secret_key_for_devise_jwt_experthub_api_must_be_changed_in_prod_123456789"
        ).first
        current_user = User.find_by(id: jwt_payload["sub"] || jwt_payload["user_id"])
      rescue => e
        # ignore decoding errors and check warden status
      end
    end

    # Fallback to devise current_user if header decode failed
    current_user ||= current_user_user

    if current_user
      render json: {
        status: 200,
        message: "Logged out successfully."
      }, status: :ok
    else
      render json: {
        status: 401,
        message: "Active session not found."
      }, status: :unauthorized
    end
  end

  # Helper method because devise may define current_user or current_resource
  def current_user_user
    warden.authenticate(scope: :user)
  end
end
