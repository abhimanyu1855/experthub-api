# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    render json: {
      status: { code: 200, message: "Logged in successfully." },
      data: UserBlueprint.render_as_hash(resource)
    }, status: :ok
  end

  def respond_to_on_destroy
    # Decode the JWT to find the user, then revoke via JTI rotation.
    # JTIMatcher stores the current JTI in users.jti — rotating it instantly
    # invalidates ALL outstanding tokens for this user on logout.
    token = request.headers["Authorization"].to_s.split(" ").last

    if token.present?
      begin
        payload = JWT.decode(
          token,
          Devise.jwt_secret,
          true,                          # verify signature
          algorithms: ["HS256"]
        ).first

        user = User.find_by(id: payload["sub"] || payload["user_id"])

        if user
          # sign_out triggers Devise::JWT::RevocationStrategies::JTIMatcher#revoke_jwt
          # which rotates user.jti — the old token is immediately invalid.
          sign_out(user)
          render json: { status: 200, message: "Logged out successfully." }, status: :ok
          return
        end
      rescue JWT::DecodeError, JWT::ExpiredSignature => e
        Rails.logger.warn "[SessionsController] Logout with invalid JWT: #{e.class}"
        # Token is already invalid — treat as already logged out.
      end
    end

    render json: { status: 401, message: "Active session not found." }, status: :unauthorized
  end
end
