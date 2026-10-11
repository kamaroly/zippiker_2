defmodule Zippiker.HR.Workers do
  @moduledoc "Shared helpers for the HR background jobs."

  @doc "Workspaces with the HR module switched on."
  def workspaces do
    Zippiker.Accounts.Organization
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(:hr in &1.enabled_modules))
  end
end
