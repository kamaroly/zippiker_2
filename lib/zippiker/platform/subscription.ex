defmodule Zippiker.Platform.Subscription do
  @moduledoc """
  One per workspace: its plan, billing status and current billing period.
  Created when the workspace is created (`ensure`), changed by super admins.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Platform.Subscription.Attributes,
      Zippiker.Platform.Subscription.Relationships,
      Zippiker.Platform.Subscription.Actions,
      Zippiker.Platform.Subscription.Policies
    ]

  postgres do
    table "subscriptions"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :plan, on_delete: :restrict
    end
  end

  identities do
    identity :unique_organization, [:organization_id]
  end
end
