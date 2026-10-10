defmodule ZippikerWeb.ExpenseLive.Workflows do
  @moduledoc """
  Expense approval workflows: initiator → approver 1 … approver n, the last
  being the final approver. Each approver is the initiator's manager, a
  specific person, anyone in a group, or any workspace admin. Several
  workflows can apply from different amounts (the highest threshold not
  above the claim total wins).
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Workflow

  @types [
    {"Initiator's manager", "manager"},
    {"Specific person", "user"},
    {"Anyone in a group", "group"},
    {"Any workspace admin", "admins"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    {:ok,
     socket
     |> assign(
       page_title: "Approval workflows",
       types: @types,
       members: member_options(socket.assigns),
       groups: Workflow.list_approval_groups!(opts),
       currency: Zippiker.Accounts.default_legal_entity!(opts).currency
     )
     |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket,
      workflow: nil,
      editing?: true,
      fields: %{"name" => "Expense approval", "min_amount" => "0", "active?" => "true"},
      steps: [new_step("manager", "Line manager"), new_step("admins", "Finance sign-off")]
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    workflow = Enum.find(socket.assigns.workflows, &(&1.id == id))

    assign(socket,
      workflow: workflow,
      editing?: true,
      fields: %{
        "name" => workflow.name,
        "min_amount" => Decimal.to_string(workflow.min_amount, :normal),
        "active?" => to_string(workflow.active?)
      },
      steps:
        Enum.map(workflow.steps, fn step ->
          %{
            "key" => step.id,
            "approver_type" => to_string(step.approver_type),
            "user_id" => step.user_id || "",
            "group_id" => step.group_id || "",
            "label" => step.label || ""
          }
        end)
    )
  end

  defp apply_action(socket, :index, _params), do: assign(socket, workflow: nil, editing?: false)

  defp new_step(type, label) do
    %{
      "key" => Ash.UUID.generate(),
      "approver_type" => type,
      "user_id" => "",
      "group_id" => "",
      "label" => label
    }
  end

  @impl true
  def handle_event("change", params, socket), do: {:noreply, assign_params(socket, params)}

  def handle_event("add_step", _params, socket) do
    {:noreply, update(socket, :steps, &(&1 ++ [new_step("user", "")]))}
  end

  def handle_event("remove_step", %{"key" => key}, socket) do
    {:noreply, update(socket, :steps, fn steps -> Enum.reject(steps, &(&1["key"] == key)) end)}
  end

  def handle_event("move_step", %{"key" => key, "by" => by}, socket) do
    steps = socket.assigns.steps
    from = Enum.find_index(steps, &(&1["key"] == key))
    to = from + String.to_integer(by)

    steps =
      if to in 0..(length(steps) - 1),
        do: steps |> List.delete_at(from) |> List.insert_at(to, Enum.at(steps, from)),
        else: steps

    {:noreply, assign(socket, :steps, steps)}
  end

  def handle_event("save", params, socket) do
    socket = assign_params(socket, params)
    fields = socket.assigns.fields

    attrs = %{
      name: fields["name"],
      min_amount: if(fields["min_amount"] in [nil, ""], do: "0", else: fields["min_amount"]),
      active?: fields["active?"] == "true",
      steps:
        Enum.map(socket.assigns.steps, fn step ->
          %{
            "approver_type" => step["approver_type"],
            "label" => blank_to_nil(step["label"]),
            "user_id" => if(step["approver_type"] == "user", do: blank_to_nil(step["user_id"])),
            "group_id" => if(step["approver_type"] == "group", do: blank_to_nil(step["group_id"]))
          }
        end)
    }

    result =
      case socket.assigns.workflow do
        nil ->
          Workflow.create_approval_workflow(
            Map.put(attrs, :document_type, :expense_claim),
            ash_opts(socket)
          )

        workflow ->
          Workflow.update_approval_workflow(workflow, attrs, ash_opts(socket))
      end

    case result do
      {:ok, _workflow} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workflow saved")
         |> load()
         |> push_patch(to: ~p"/expenses/workflows")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    workflow = Enum.find(socket.assigns.workflows, &(&1.id == id))

    case Workflow.delete_approval_workflow(workflow, ash_opts(socket)) do
      :ok -> {:noreply, socket |> put_flash(:info, "Workflow deleted") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp assign_params(socket, params) do
    fields = Map.merge(socket.assigns.fields, Map.get(params, "workflow", %{}))
    rows = Map.get(params, "steps", %{})

    steps =
      Enum.map(socket.assigns.steps, fn step ->
        Map.merge(
          step,
          Map.take(Map.get(rows, step["key"], %{}), ~w(approver_type user_id group_id label))
        )
      end)

    assign(socket, fields: fields, steps: steps)
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp load(socket) do
    assign(
      socket,
      :workflows,
      Workflow.list_approval_workflows!(%{document_type: :expense_claim}, ash_opts(socket))
    )
  end

  defp threshold(workflow, currency) do
    if Decimal.eq?(workflow.min_amount, 0),
      do: "All claims",
      else: "Claims from #{ZippikerWeb.Format.money(Money.new!(currency, workflow.min_amount))}"
  end
end
