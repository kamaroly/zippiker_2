defmodule ZippikerWeb.Platform.PlansLive do
  @moduledoc "The price list: per-seat price, seat limit, included modules, trial, default."
  use ZippikerWeb, :live_view

  alias Zippiker.Platform

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Plans") |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    form =
      Platform.Plan
      |> AshPhoenix.Form.for_create(:create, as: "plan", actor: socket.assigns.current_user)
      |> to_form()

    assign(socket, form: form, plan: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    plan = Platform.get_plan!(id, actor: socket.assigns.current_user)

    form =
      plan
      |> AshPhoenix.Form.for_update(:update, as: "plan", actor: socket.assigns.current_user)
      |> to_form()

    assign(socket, form: form, plan: plan)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, plan: nil)

  @impl true
  def handle_event("validate", %{"plan" => params}, socket) do
    {:noreply,
     assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, clean(params)))}
  end

  def handle_event("save", %{"plan" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: clean(params)) do
      {:ok, _plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Plan saved")
         |> load()
         |> push_patch(to: ~p"/platform/plans")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  # The hidden "" keeps an all-unchecked module list submittable.
  defp clean(params),
    do: Map.update(params, "modules", [], fn modules -> Enum.reject(modules, &(&1 == "")) end)

  defp load(socket),
    do:
      stream(socket, :plans, Platform.list_plans!(actor: socket.assigns.current_user),
        reset: true
      )

  defp checked?(form, key) do
    key = to_string(key)
    form[:modules].value |> List.wrap() |> Enum.any?(&(to_string(&1) == key))
  end
end
