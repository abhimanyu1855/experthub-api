# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_tenant

    def connect
      self.current_user   = find_verified_user
      self.current_tenant = find_verified_tenant
    end

    private

    def find_verified_user
      token = request.params[:token] || request.headers["Authorization"]&.sub(/^Bearer /, "")
      return reject_unauthorized_connection unless token

      payload = Warden::JWTAuth::TokenDecoder.new.call(token)
      user = User.find_by(id: payload["user_id"])
      user || reject_unauthorized_connection
    rescue JWT::DecodeError
      reject_unauthorized_connection
    end

    def find_verified_tenant
      ident = request.params[:tenant] || extract_subdomain
      return reject_unauthorized_connection unless ident

      Tenant.find_by(ident: ident) || reject_unauthorized_connection
    end

    def extract_subdomain
      app_domain = ENV.fetch("APP_DOMAIN", "experthub.localhost")
      host = request.host
      return nil if host == app_domain || %w[localhost 127.0.0.1].include?(host)

      host.sub(/\.#{Regexp.escape(app_domain)}$/, "").presence
    end
  end
end
