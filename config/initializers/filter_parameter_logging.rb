# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  # Auth & credentials
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp,
  # PII
  :email, :phone, :phone_number, :ssn,
  # Payment — PCI DSS
  :cvv, :cvc, :card_number, :stripe_secret, :razorpay_secret,
  # HTTP headers — Authorization header carries the JWT bearer token
  :authorization
]
