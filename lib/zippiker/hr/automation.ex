defmodule Zippiker.HR.Automation do
  @moduledoc """
  Leave jobs run by Oban (`Zippiker.HR.Workers`) for every workspace, and on
  demand by admins: crediting accruals, and applying the overdue action to
  requests nobody reviewed within their policy's threshold.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Zippiker.HR.Automation.Actions]

  policies do
    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
