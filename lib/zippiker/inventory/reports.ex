defmodule Zippiker.Inventory.Reports do
  @moduledoc "Stock levels and valuation, exposed as generic actions."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Inventory,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.Inventory.Reports.Actions, Zippiker.Inventory.Reports.Policies]
end
