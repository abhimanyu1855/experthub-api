# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  def create
    build_resource(sign_up_params)

    # Skip confirmation in non-production so onboarding is frictionless during dev/test
    resource.skip_confirmation! if Rails.env.development? || Rails.env.test?

    resource.save
    yield resource if block_given?
    if resource.persisted?
      if Current.tenant
        # SECURITY: Only 'client' and 'expert' are allowed via public registration.
        # 'operator' is a privileged role — it MUST be created by an existing operator
        # through the admin panel (Admin::UsersController), never via self-signup.
        allowed_roles = %w[client expert]
        role = params[:role].to_s.downcase
        role = "client" unless allowed_roles.include?(role)

        Membership.create!(
          user: resource,
          tenant: Current.tenant,
          role: role,
          status: :active
        )

        # Experts start as 'pending' — an operator must approve them before they
        # can list services. Auto-approval would let anyone publish services immediately.
        if role == "expert"
          ExpertProfile.create!(
            user: resource,
            tenant: Current.tenant,
            specialization: params[:specialization],
            bio: params[:bio],
            title: params[:title],
            approval_status: :pending
          )
        end
      end

      if resource.active_for_authentication?
        sign_in(resource_name, resource, store: false)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end

    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  private

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render json: {
        status: { code: 200, message: "Signed up successfully." },
        data: UserBlueprint.render_as_hash(resource)
      }, status: :ok
    else
      render json: {
        status: { message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :given_name, :family_name, :display_name, :phone_number, :referred_by_code)
  end
end

