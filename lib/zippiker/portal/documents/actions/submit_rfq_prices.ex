defmodule Zippiker.Portal.Documents.Actions.SubmitRfqPrices do
  @moduledoc """
  The supplier's reply: unit prices per line (lines not priced keep theirs)
  and their reference; the request is then marked quoted.
  """
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Portal.Access
  alias Zippiker.Portal.Documents.Actions.Document

  @impl true
  def run(input, _opts, context) do
    args = input.arguments

    with {:ok, rfq, organization} <-
           Document.fetch(
             context.actor,
             args.access_id,
             :supplier,
             Zippiker.Purchasing.Rfq,
             :supplier_id,
             args.rfq_id
           ),
         :ok <-
           if(rfq.status in [:sent, :quoted], do: :ok, else: {:error, "this request is closed"}) do
      opts = Access.opts(organization)

      lines =
        Enum.map(rfq.lines, fn line ->
          price = Map.get(args.prices, line.id) || Map.get(args.prices, to_string(line.id))

          %{
            "id" => line.id,
            "unit_price" => if(price in [nil, ""], do: line.unit_price, else: price)
          }
        end)

      params =
        %{lines: lines}
        |> then(
          &if(args[:reference] in [nil, ""],
            do: &1,
            else: Map.put(&1, :supplier_reference, args.reference)
          )
        )

      with {:ok, rfq} <- rfq |> Ash.Changeset.for_update(:update, params, opts) |> Ash.update(),
           {:ok, rfq} <-
             if(rfq.status == :quoted,
               do: {:ok, rfq},
               else: rfq |> Ash.Changeset.for_update(:mark_quoted, %{}, opts) |> Ash.update()
             ) do
        {:ok, rfq}
      end
    end
  end
end
