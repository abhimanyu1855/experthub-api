# frozen_string_literal: true

module Localizable
  extend ActiveSupport::Concern

  class_methods do
    def localizable_attributes(*attrs)
      attrs.each do |attr|
        define_method(attr) do
          locale_str = I18n.locale.to_s
          translations_hash = self.translations || {}

          if translations_hash.key?(locale_str) && translations_hash[locale_str].present?
            translations_hash[locale_str]
          else
            self[attr]
          end
        end
      end
    end
  end
end
