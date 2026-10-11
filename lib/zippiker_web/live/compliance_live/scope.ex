defmodule ZippikerWeb.ComplianceLive.Scope do
  @moduledoc """
  Which company the secretarial pages show: `?company=<profile id>`, else
  the first company profile (most teams have one).
  """
  import Phoenix.Component, only: [assign: 3]
  import ZippikerWeb.LiveHelpers, only: [ash_opts: 1]

  def assign_profile(socket, params \\ %{}) do
    profiles = Zippiker.Compliance.list_company_profiles!(ash_opts(socket))

    profile =
      Enum.find(profiles, &(&1.id == params["company"])) || List.first(profiles)

    socket
    |> assign(:profiles, profiles)
    |> assign(:profile, profile)
  end
end
