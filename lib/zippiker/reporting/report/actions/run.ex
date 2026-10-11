defmodule Zippiker.Reporting.Report.Actions.Run do
  @moduledoc """
  Looks the report up in the catalog, checks the workspace has its modules,
  works out the period and runs it. The result is the report's table plus
  `:title`, `:period`, `:from` and `:to`.
  """
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Reporting.{Catalog, Context}

  @impl true
  def run(input, _opts, _context) do
    organization = Context.organization(input.tenant)
    key = input.arguments.key

    case Enum.find(Catalog.available(organization), &(&1.key == key)) do
      nil ->
        {:error, Ash.Error.Query.NotFound.exception(resource: __MODULE__, primary_key: key)}

      report ->
        context = Context.new(input.tenant, organization, report, input.arguments)
        {module, function} = report.run

        {:ok,
         module
         |> apply(function, [context])
         |> Map.merge(%{
           title: report.title,
           period: report.period,
           from: context.from,
           to: context.to
         })}
    end
  end
end
