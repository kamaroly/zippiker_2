defmodule Zippiker.Sales.Reports do
  @moduledoc "Read-only sales reporting, exposed as generic actions."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.Sales.Reports.Actions, Zippiker.Sales.Reports.Policies]
end
