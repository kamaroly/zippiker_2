defmodule Zippiker.Accounting.Reports do
  @moduledoc "Financial statements computed from journal lines, exposed as generic actions."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounting,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.Accounting.Reports.Actions, Zippiker.Accounting.Reports.Policies]
end
