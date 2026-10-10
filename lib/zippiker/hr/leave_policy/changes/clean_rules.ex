defmodule Zippiker.HR.LeavePolicy.Changes.CleanRules do
  @moduledoc """
  Normalizes the rules form: keeps only included types, turns blank days into
  "no limit", and reuses existing rule ids so entitlements are updated in place.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    existing =
      changeset.data
      |> Ash.load!(:rules, tenant: changeset.tenant, authorize?: false)
      |> Map.fetch!(:rules)
      |> Map.new(&{&1.leave_type_id, &1.id})

    rules =
      for rule <- Ash.Changeset.get_argument(changeset, :rules) || [],
          get(rule, :included) not in [false, "false"],
          type_id = get(rule, :leave_type_id),
          type_id not in [nil, ""] do
        %{
          id: existing[type_id],
          leave_type_id: type_id,
          days_per_year: blank_to_nil(get(rule, :days_per_year)),
          carry_over_days: blank_to_nil(get(rule, :carry_over_days)) || "0"
        }
        |> Map.reject(fn {key, value} -> key == :id and is_nil(value) end)
      end

    Ash.Changeset.force_set_argument(changeset, :rules, rules)
  end

  defp get(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
