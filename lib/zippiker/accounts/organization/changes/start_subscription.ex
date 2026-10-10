defmodule Zippiker.Accounts.Organization.Changes.StartSubscription do
  @moduledoc """
  Puts a new workspace on the platform's default plan (see
  `Zippiker.Platform.Subscription`), which also sets its modules and seat limit.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, organization ->
      case Zippiker.Platform.ensure_subscription(organization.id, authorize?: false) do
        {:ok, _subscription} ->
          {:ok, Ash.get!(Zippiker.Accounts.Organization, organization.id, authorize?: false)}

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
