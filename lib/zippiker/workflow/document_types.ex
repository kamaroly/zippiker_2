defmodule Zippiker.Workflow.DocumentTypes do
  @moduledoc """
  The documents that can go through an approval workflow. To make another
  document approvable (leave, change requests, journal postings…): add it
  here, start `Zippiker.Workflow.start_approval/2` from its submit action,
  and handle the outcome in `Zippiker.Workflow.Callbacks.finished/2`.
  """

  @types [
    %{key: :expense_claim, label: "Expense claims", module: :expenses}
  ]

  @doc "Every approvable document type: `%{key, label, module}`."
  def all, do: @types

  @doc "The document type keys (used as attribute constraints)."
  def keys, do: Enum.map(@types, & &1.key)

  def label(key), do: Enum.find_value(@types, to_string(key), &(&1.key == key && &1.label))
end
