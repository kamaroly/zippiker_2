defmodule Zippiker.Accounts.User do
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication],
    fragments: [
      Zippiker.Accounts.User.Attributes,
      Zippiker.Accounts.User.Relationships,
      Zippiker.Accounts.User.Calculations,
      Zippiker.Accounts.User.Aggregates,
      Zippiker.Accounts.User.Actions,
      Zippiker.Accounts.User.Policies
    ]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at
        auto_confirm_actions [:sign_in_with_magic_link, :reset_password_with_token]
        sender Zippiker.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource Zippiker.Accounts.Token
      signing_secret Zippiker.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hash_provider AshAuthentication.BcryptProvider

        resettable do
          sender Zippiker.Accounts.User.Senders.SendPasswordResetEmail
          # these configurations will be the default in a future release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end

      remember_me :remember_me
    end
  end

  postgres do
    table "users"
    repo Zippiker.Repo
  end

  identities do
    identity :unique_email, [:email]
  end
end
