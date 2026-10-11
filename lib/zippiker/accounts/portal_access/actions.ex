defmodule Zippiker.Accounts.PortalAccess.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Accounts.PortalAccess.Changes

  actions do
    defaults [:read]

    read :for_party do
      argument :party_id, :uuid, allow_nil?: false
      filter expr(party_id == ^arg(:party_id) and status != :revoked)
      prepare build(sort: [inserted_at: :desc], load: [:user])
    end

    read :mine do
      description "The actor's active portals, across teams."
      multitenancy :allow_global
      filter expr(user_id == ^actor(:id) and status == :active)
      prepare build(sort: [inserted_at: :asc], load: [:organization])
    end

    read :by_token do
      multitenancy :allow_global
      argument :token, :string, allow_nil?: false, sensitive?: true
      filter expr(token == ^arg(:token) and status == :invited)
      prepare build(load: [:organization])
    end

    create :invite do
      accept [:email, :kind, :party_id, :party_name]
      change relate_actor(:invited_by)
      change Changes.Prepare
      change Changes.SendInvitation
    end

    update :accept do
      description "The invitee (signed in) claims the portal."
      require_atomic? false
      change relate_actor(:user)
      change set_attribute(:status, :active)
      change set_attribute(:accepted_at, &DateTime.utc_now/0)
    end

    update :revoke do
      change set_attribute(:status, :revoked)
    end
  end
end
