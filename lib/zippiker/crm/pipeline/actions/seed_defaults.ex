defmodule Zippiker.Crm.Pipeline.Actions.SeedDefaults do
  @moduledoc "Returns the first pipeline, creating a sensible default one if none exists."
  use Ash.Resource.Actions.Implementation

  @stages [
    {"Qualified", 10, :open, :slate},
    {"Discovery", 25, :open, :blue},
    {"Proposal", 50, :open, :violet},
    {"Negotiation", 75, :open, :amber},
    {"Won", 100, :won, :emerald},
    {"Lost", 0, :lost, :rose}
  ]

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]

    case Zippiker.Crm.list_pipelines(opts) do
      {:ok, [pipeline | _]} ->
        {:ok, pipeline}

      {:ok, []} ->
        Ash.transact(Zippiker.Crm.Pipeline, fn ->
          pipeline = Zippiker.Crm.create_pipeline!(%{name: "Sales pipeline"}, opts)

          @stages
          |> Enum.with_index()
          |> Enum.each(fn {{name, probability, kind, color}, position} ->
            Zippiker.Crm.create_stage!(
              %{
                pipeline_id: pipeline.id,
                name: name,
                probability: probability,
                kind: kind,
                color: color,
                position: position
              },
              opts
            )
          end)

          Ash.load!(pipeline, :stages, opts)
        end)

      error ->
        error
    end
  end
end
