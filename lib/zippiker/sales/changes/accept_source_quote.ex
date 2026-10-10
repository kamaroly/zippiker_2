defmodule Zippiker.Sales.Changes.AcceptSourceQuote do
  @moduledoc """
  Turning a draft or sent quote into an order or invoice means the customer
  said yes: the quote is accepted (which also wins its deal).
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, document ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      with id when is_binary(id) <- document.quote_id,
           {:ok, %{status: status} = quote} when status in [:draft, :sent] <-
             Zippiker.Sales.get_quote(id, opts),
           {:ok, _quote} <- Zippiker.Sales.accept_quote(quote, opts) do
        {:ok, document}
      else
        {:error, error} -> {:error, error}
        _ -> {:ok, document}
      end
    end)
  end
end
