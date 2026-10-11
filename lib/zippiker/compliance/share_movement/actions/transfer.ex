defmodule Zippiker.Compliance.ShareMovement.Actions.Transfer do
  @moduledoc "A transfer: out of the seller's holding, into the buyer's, in one transaction."
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Zippiker.Compliance.{ShareMovement, Shareholder}

  @impl true
  def run(input, _opts, context) do
    args = input.arguments
    opts = [tenant: input.tenant, actor: context.actor, authorize?: false]
    date = args[:date] || Date.utc_today()

    held =
      ShareMovement
      |> Ash.Query.filter(
        shareholder_id == ^args.from_id and share_class_id == ^args.share_class_id
      )
      |> Ash.sum!(:quantity, opts)
      |> case do
        nil -> 0
        sum -> sum
      end

    if held < args.quantity do
      {:error, "the seller only holds #{held} shares of this class"}
    else
      common = %{
        profile_id: args.profile_id,
        share_class_id: args.share_class_id,
        date: date,
        consideration: args[:consideration],
        certificate_number: args[:certificate_number]
      }

      out =
        record(
          Map.merge(common, %{
            shareholder_id: args.from_id,
            quantity: -args.quantity,
            kind: :transfer_out
          }),
          opts
        )

      into =
        record(
          Map.merge(common, %{
            shareholder_id: args.to_id,
            quantity: args.quantity,
            kind: :transfer_in
          }),
          opts
        )

      if held == args.quantity do
        Shareholder
        |> Ash.get!(args.from_id, opts)
        |> Ash.Changeset.for_update(:update, %{ceased_on: date}, opts)
        |> Ash.update!(authorize?: false)
      end

      {:ok, %{out: out, in: into}}
    end
  end

  defp record(params, opts) do
    ShareMovement
    |> Ash.Changeset.for_create(:record, params, opts)
    |> Ash.create!(authorize?: false)
  end
end
