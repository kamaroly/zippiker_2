defmodule Zippiker.Compliance.ShareMovement do
  @moduledoc """
  A change in a member's shares: an allotment (new shares), either side of
  a transfer, or a cancellation. Signed quantity; holdings are the sum.
  Allotments add a return of allotment to the filing calendar.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.ShareMovement.Attributes,
      Zippiker.Compliance.ShareMovement.Relationships,
      Zippiker.Compliance.ShareMovement.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "share_movements"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
      reference :shareholder, on_delete: :delete
      reference :share_class, on_delete: :restrict
    end
  end

  multitenancy do
    strategy :context
  end
end
