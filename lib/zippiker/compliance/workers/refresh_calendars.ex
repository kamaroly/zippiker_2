defmodule Zippiker.Compliance.Workers.RefreshCalendars do
  @moduledoc "Daily (Oban cron): keeps every company's filing calendar up to date."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    for organization <- Zippiker.Accounts.Organization |> Ash.read!(authorize?: false),
        :compliance in organization.enabled_modules do
      Zippiker.Compliance.refresh_filing_calendars!(%{}, tenant: organization, authorize?: false)
    end

    :ok
  end
end
