# frozen_string_literal: true

require "omniauth/strategies/oauth2"

module OmniAuth
  module Strategies
    class Slack < OmniAuth::Strategies::OAuth2
      option :name, "slack"

      option :authorize_options, %i[user_scope scope]

      option :client_options, {
        site: "https://slack.com",
        token_url: "/api/oauth.v2.access",
        authorize_url: "/oauth/v2/authorize"
      }

      option :auth_token_params, {
        mode: :header
      }

      uid { "#{identity.dig("user", "id")}-#{identity.dig("team", "id")}" }

      info do
        {
          name: identity.dig("user", "name") || identity.dig("user", "real_name"),
          email: identity.dig("user", "email"),
          image: identity.dig("user", "image_48")
        }
      end

      extra do
        hash = {
          "raw_info" => raw_info,
          "token_type" => access_token.params["token_type"]
        }
        hash["bot_info"] = bot_info if access_token.params["token_type"] == "bot"
        hash
      end

      def bot_info
        @bot_info ||= access_token.get("/api/users.profile.get").parsed["profile"]
      end

      def identity
        @identity ||= {
          "user" => raw_info["user"] || raw_info["profile"],
          "team" => raw_info["team"] || access_token.params["team"]
        }
        @identity["user"]["id"] ||= access_token.params["authed_user"]["id"]
        @identity
      end

      def raw_info
        if access_token.params["token_type"] == "bot"
          user_id = access_token.params["authed_user"]["id"]
          url = "/api/users.profile.get?user=#{user_id}"
          @raw_info ||= access_token.get(url).parsed
        else
          @raw_info ||= access_token.get("/api/users.identity").parsed
        end
      end

      def callback_url
        full_host + script_name + callback_path
      end

      def client
        ::OAuth2::SlackClient.new(options.client_id, options.client_secret, deep_symbolize(options.client_options))
      end

      def callback_phase
        error = request.params["error_reason"] || request.params["error"]
        if csrf_check_failed?
          fail!(:csrf_detected, CallbackError.new(:csrf_detected, "CSRF detected"))
        elsif error
          handle_callback_error(error)
        else
          process_successful_callback
        end
      rescue ::OAuth2::Error, CallbackError => e
        fail!(:invalid_credentials, e)
      rescue ::Timeout::Error, ::Errno::ETIMEDOUT, ::OAuth2::TimeoutError, ::OAuth2::ConnectionError => e
        fail!(:timeout, e)
      rescue ::SocketError => e
        fail!(:failed_to_connect, e)
      end

      def auth_hash
        credentials_data = credentials
        extra_data = extra
        AuthHash.new(provider: name, uid: uid).tap do |auth|
          auth.info = info unless skip_info?
          auth.credentials = credentials_data if credentials_data
          auth.extra = extra_data if extra_data
        end
      end

      def credentials
        hash = { "token" => access_token.token }
        expires = access_token.expires_at.present? || access_token.expires_in.present?
        hash["refresh_token"] = access_token.refresh_token if expires && access_token.refresh_token
        hash["expires_at"] = access_token.expires_at if access_token.expires_at
        hash["expires_in"] = access_token.expires_in if access_token.expires_in
        hash["expires"] = expires
        hash
      end

      protected

      def csrf_check_failed?
        !options.provider_ignores_state &&
          (request.params["state"].to_s.empty? ||
            !secure_compare(request.params["state"], session.delete("omniauth.state")))
      end


      def secure_compare(string_a, string_b)
        return false unless string_a.bytesize == string_b.bytesize

        l = string_a.unpack "C#{string_a.bytesize}"

        res = 0
        string_b.each_byte { |byte| res |= byte ^ l.shift }
        res.zero?
      end

      def handle_callback_error(error)
        fail!(
          error,
          CallbackError.new(
            request.params["error"],
            request.params["error_description"] || request.params["error_reason"],
            request.params["error_uri"]
          )
        )
      end

      def process_successful_callback
        self.access_token = build_access_token
        self.access_token = access_token.refresh! if access_token.expired?
        env["omniauth.auth"] = auth_hash
        call_app!
      end
    end
  end
end
