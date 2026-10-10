defmodule Zippiker.Purchasing.Reports do
  @moduledoc "Payables headline numbers, exposed as a generic action."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.Purchasing.Reports.Actions, Zippiker.Purchasing.Reports.Policies]
end
