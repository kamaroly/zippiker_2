defmodule Zippiker.Compliance.Changes.AddFiling do
  @moduledoc """
  Puts the filing a change triggers on the company's calendar:
  director/secretary appointed or ceased → notify the Registrar within 14
  days; shares allotted → return of allotment within 30 days; beneficial
  owners added, changed or ceased → update within 30 days; charge created →
  register within 30 days; charge satisfied → memorandum of satisfaction.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, opts, _context) do
    event = Keyword.fetch!(opts, :event)

    Ash.Changeset.after_action(changeset, fn changeset, record ->
      case filing(event, record) do
        nil ->
          {:ok, record}

        task ->
          Zippiker.Compliance.ComplianceTask
          |> Ash.Changeset.for_create(:create, Map.put(task, :profile_id, record.profile_id),
            tenant: changeset.tenant,
            authorize?: false
          )
          |> Ash.create()
          |> case do
            {:ok, _task} -> {:ok, record}
            error -> error
          end
      end
    end)
  end

  defp filing(:appointed, officer),
    do: %{
      kind: :officer_change,
      title: "Notify the Registrar: #{role(officer)} #{officer.name} appointed",
      due_on: Date.add(officer.appointed_on, 14)
    }

  defp filing(:ceased, officer),
    do: %{
      kind: :officer_change,
      title: "Notify the Registrar: #{role(officer)} #{officer.name} ceased",
      due_on: Date.add(officer.ceased_on, 14)
    }

  defp filing(:allotted, movement),
    do: %{
      kind: :allotment_return,
      title:
        "Return of allotment: #{movement.quantity} shares (#{Calendar.strftime(movement.date, "%-d %b %Y")})",
      due_on: Date.add(movement.date, 30)
    }

  defp filing(event, owner) when event in [:owner_added, :owner_changed, :owner_ceased] do
    on =
      case event do
        :owner_added -> owner.became_owner_on
        :owner_ceased -> owner.ceased_on
        :owner_changed -> Date.utc_today()
      end

    what = %{owner_added: "added", owner_changed: "changed", owner_ceased: "ceased"}[event]

    %{
      kind: :beneficial_ownership,
      title: "Beneficial ownership update: #{owner.name} #{what}",
      description: "Lodge the updated register of beneficial owners with the Registrar.",
      due_on: Date.add(on, 30)
    }
  end

  defp filing(:charge_created, charge),
    do: %{
      kind: :charge_registration,
      title: "Register charge in favour of #{charge.chargee}",
      due_on: Date.add(charge.created_on, 30)
    }

  defp filing(:charge_satisfied, charge),
    do: %{
      kind: :charge_satisfaction,
      title: "Memorandum of satisfaction: charge to #{charge.chargee}",
      due_on: Date.add(charge.satisfied_on, 30)
    }

  defp filing(_event, _record), do: nil

  defp role(%{role: role}), do: role |> to_string() |> String.replace("_", " ")
end
