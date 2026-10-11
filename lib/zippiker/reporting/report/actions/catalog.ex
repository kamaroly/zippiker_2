defmodule Zippiker.Reporting.Report.Actions.Catalog do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Reporting.{Catalog, Context}

  @impl true
  def run(input, _opts, _context) do
    organization = Context.organization(input.tenant)
    {:ok, organization |> Catalog.available() |> Enum.map(&Map.delete(&1, :run))}
  end
end
