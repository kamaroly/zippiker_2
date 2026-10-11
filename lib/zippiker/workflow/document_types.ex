defmodule Zippiker.Workflow.DocumentTypes do
  @moduledoc """
  The documents that can go through an approval workflow. To make another
  document approvable (leave, change requests, journal postings…): add it
  here, start `Zippiker.Workflow.start_approval/2` from its submit action,
  and handle the outcome in `Zippiker.Workflow.Callbacks.finished/2`.
  """

  @types [
    %{
      key: :expense_claim,
      label: "Expense claims",
      module: :expenses,
      unit: :money,
      default_steps: [%{position: 1, label: "Workspace admin", approver_type: :admins}]
    },
    %{
      key: :leave_request,
      label: "Leave requests",
      module: :hr,
      unit: :days,
      default_steps: [%{position: 1, label: "Line manager", approver_type: :manager_or_admins}]
    }
  ]

  @doc """
  Every approvable document type: `%{key, label, module, unit, default_steps}`.
  `unit` is what a workflow's minimum amount measures (`:money` or `:days`);
  `default_steps` apply when the workspace has no workflow for the type.
  """
  def all, do: @types

  @doc "The document type keys (used as attribute constraints)."
  def keys, do: Enum.map(@types, & &1.key)

  def label(key), do: Enum.find_value(@types, to_string(key), &(&1.key == key && &1.label))

  def get(key), do: Enum.find(@types, &(&1.key == key))

  def default_steps(key), do: get(key).default_steps
end
