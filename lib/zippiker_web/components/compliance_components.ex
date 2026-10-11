defmodule ZippikerWeb.ComplianceComponents do
  @moduledoc "Company secretarial building blocks: filing state badges, setup prompt."
  use Phoenix.Component
  use ZippikerWeb, :verified_routes

  import ZippikerWeb.CoreComponents

  attr :state, :atom, required: true

  def filing_state(assigns) do
    ~H"""
    <.badge color={%{done: :emerald, overdue: :rose, due_soon: :amber, upcoming: :slate}[@state]}>
      {%{done: "Filed", overdue: "Overdue", due_soon: "Due soon", upcoming: "Upcoming"}[@state]}
    </.badge>
    """
  end

  @doc "Shown on register pages until the company's profile exists."
  def setup_needed(assigns) do
    ~H"""
    <.card id="setup-company">
      <.empty_state icon="hero-building-library" title="Set up your company first">
        Add the company's registration details to start its registers and filing calendar.
        <:action>
          <.button navigate={~p"/compliance"} variant="primary">Company details</.button>
        </:action>
      </.empty_state>
    </.card>
    """
  end

  def company_type_label(:private_limited), do: "Private company limited by shares"
  def company_type_label(:public_limited), do: "Public company limited by shares"
  def company_type_label(:guarantee), do: "Company limited by guarantee"
  def company_type_label(:unlimited), do: "Unlimited company"
  def company_type_label(:foreign), do: "Foreign company (branch)"
  def company_type_label(_), do: "—"

  def officer_role_label(role),
    do: role |> to_string() |> String.replace("_", " ") |> String.capitalize()
end
