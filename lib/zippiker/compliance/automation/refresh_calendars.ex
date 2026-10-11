defmodule Zippiker.Compliance.Automation.RefreshCalendars do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    today = input.arguments[:today] || Date.utc_today()

    added =
      Zippiker.Compliance.CompanyProfile
      |> Ash.read!(tenant: input.tenant, authorize?: false)
      |> Enum.map(&Zippiker.Compliance.Calendar.refresh(&1, input.tenant, today))
      |> Enum.sum()

    {:ok, %{checked: added}}
  end
end
