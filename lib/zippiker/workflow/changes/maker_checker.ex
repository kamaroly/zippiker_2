defmodule Zippiker.Workflow.Changes.MakerChecker do
  @moduledoc """
  Holds a change for approval when maker-checker covers `scope`: records a
  `ChangeRequest` (outside the action's transaction, so it's kept) and stops
  the action with `Zippiker.Workflow.Errors.ChangeRequested`. Changes made
  by the system (no actor) or applying an approved request go through.
  """
  use Ash.Resource.Change

  alias Zippiker.Workflow.MakerChecker

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, opts, context) do
    scope = Keyword.fetch!(opts, :scope)

    if holds?(changeset, scope, context),
      do: Ash.Changeset.before_transaction(changeset, &hold(&1, scope, context.actor)),
      else: changeset
  end

  # Changes run atomically unless maker-checker holds them: holding needs a
  # hook before the transaction, which atomic actions don't run, so only then
  # the action falls back to a regular (non-atomic) run.
  @impl true
  def atomic(changeset, opts, context) do
    if holds?(changeset, Keyword.fetch!(opts, :scope), context),
      do: {:not_atomic, "held for maker-checker approval"},
      else: {:ok, changeset}
  end

  defp holds?(changeset, scope, context) do
    not (changeset.context[:maker_checker_apply] == true) and not is_nil(context.actor) and
      MakerChecker.enabled?(changeset.tenant, scope)
  end

  defp hold(changeset, scope, actor) do
    params = %{
      scope: scope,
      resource: inspect(changeset.resource),
      action: changeset.action.name,
      action_type: changeset.action_type,
      record_id: if(changeset.action_type == :create, do: nil, else: changeset.data.id),
      record_label: label(changeset),
      params: MakerChecker.to_json(inputs(changeset)),
      changes: diff(changeset)
    }

    case Zippiker.Workflow.request_change(params,
           tenant: changeset.tenant,
           actor: actor,
           authorize?: false
         ) do
      {:ok, request} ->
        Ash.Changeset.add_error(
          changeset,
          Zippiker.Workflow.Errors.ChangeRequested.exception(
            number: request.number,
            change_request_id: request.id
          )
        )

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  # Only what the action takes as input (forms also send ids and bookkeeping).
  defp inputs(changeset) do
    action = changeset.action

    allowed =
      MapSet.new(List.wrap(action.accept) ++ Enum.map(action.arguments, & &1.name), &to_string/1)

    Map.filter(changeset.params || %{}, fn {key, _value} -> to_string(key) in allowed end)
  end

  defp label(%{action_type: :create} = changeset) do
    get =
      &(Ash.Changeset.get_argument(changeset, &1) || Ash.Changeset.get_attribute(changeset, &1))

    [get.(:name), get.(:first_name), get.(:last_name), get.(:code)]
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.join(" ")
    |> case do
      "" -> "New record"
      label -> "New: #{label}"
    end
  end

  defp label(changeset) do
    data = changeset.data

    [:number, :name, :code]
    |> Enum.map(&Map.get(data, &1))
    |> Enum.find(data.id, &(is_binary(&1) and &1 != ""))
  end

  @ignored [:id, :inserted_at, :updated_at, :organization_id, :custom_fields]

  defp diff(changeset) do
    attributes =
      for {field, to} <- changeset.attributes, field not in @ignored do
        %{
          "field" => to_string(field),
          "from" => MakerChecker.display(Map.get(changeset.data, field)),
          "to" => MakerChecker.display(to)
        }
      end

    arguments =
      for {field, to} <- changeset.arguments,
          not is_nil(to),
          not Map.has_key?(changeset.attributes, field),
          from = current(changeset.data, field),
          MakerChecker.display(from) != MakerChecker.display(to) do
        %{
          "field" => to_string(field),
          "from" => MakerChecker.display(from),
          "to" => MakerChecker.display(to)
        }
      end

    changes = attributes ++ arguments

    if changeset.action_type == :destroy,
      do: [%{"field" => "record", "from" => "kept", "to" => "removed"}],
      else: changes
  end

  defp current(data, field) do
    case Map.get(data, field) do
      %Ash.NotLoaded{} -> ""
      nil -> ""
      value -> value
    end
  end
end
