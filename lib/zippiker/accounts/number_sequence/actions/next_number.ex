defmodule Zippiker.Accounts.NumberSequence.Actions.NextNumber do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounts.NumberSequence

  @impl true
  def run(input, _opts, _context) do
    opts = [tenant: input.tenant, authorize?: false]
    yearly? = Map.get(input.arguments, :yearly?, true)
    year = if yearly?, do: (input.arguments[:date] || Date.utc_today()).year, else: 0

    with {:ok, sequence} <-
           NumberSequence
           |> Ash.Changeset.for_create(
             :open,
             %{
               legal_entity_id: input.arguments.legal_entity_id,
               document_type: input.arguments.document_type,
               year: year
             },
             opts
           )
           |> Ash.create(),
         {:ok, sequence} <-
           sequence |> Ash.Changeset.for_update(:increment, %{}, opts) |> Ash.update() do
      number = sequence.last_value |> Integer.to_string() |> String.pad_leading(4, "0")

      if yearly?,
        do: {:ok, "#{input.arguments.prefix}-#{year}-#{number}"},
        else: {:ok, "#{input.arguments.prefix}-#{number}"}
    end
  end
end
