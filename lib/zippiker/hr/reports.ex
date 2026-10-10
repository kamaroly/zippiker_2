defmodule Zippiker.HR.Reports do
  @moduledoc "People numbers, leave balances and the org chart, exposed as generic actions."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.HR.Reports.Actions, Zippiker.HR.Reports.Policies]
end
