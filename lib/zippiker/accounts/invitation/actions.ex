defmodule Zippiker.Accounts.Invitation.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Accounts.Invitation.Changes

  actions do
    defaults [:read, :destroy]

    read :pending do
      filter expr(is_nil(accepted_at))
      prepare build(sort: [inserted_at: :desc], load: [:invited_by])
    end

    read :for_me do
      description "Open invitations addressed to the actor's email."
      filter expr(email == ^actor(:email) and is_nil(accepted_at) and expires_at > now())
      prepare Zippiker.Accounts.Invitation.Preparations.LoadPublicDetails
    end

    read :by_token do
      argument :token, :string, allow_nil?: false, sensitive?: true
      get? true
      filter expr(token == ^arg(:token))
      prepare Zippiker.Accounts.Invitation.Preparations.LoadPublicDetails
    end

    create :create do
      primary? true
      accept [:email, :role]
      validate Zippiker.Accounts.Invitation.Validations.WithinSeatLimit
      change Changes.Prepare
      change relate_actor(:invited_by)
      change Changes.SendEmail
    end

    update :accept do
      require_atomic? false
      validate {Zippiker.Accounts.Invitation.Validations.Acceptable, []}
      change set_attribute(:accepted_at, &DateTime.utc_now/0)
      change Changes.CreateMembership
    end
  end
end
