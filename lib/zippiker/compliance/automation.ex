defmodule Zippiker.Compliance.Automation do
  @moduledoc "Daily (Oban): adds upcoming annual returns and AGMs for every company."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    authorizers: [Ash.Policy.Authorizer]

  actions do
    action :refresh_calendars, :map do
      argument :today, :date
      run Zippiker.Compliance.Automation.RefreshCalendars
    end
  end

  policies do
    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
