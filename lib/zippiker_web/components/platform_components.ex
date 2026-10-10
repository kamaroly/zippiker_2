defmodule ZippikerWeb.PlatformComponents do
  @moduledoc "Badges for subscriptions and platform invoices (workspace billing and super admin)."
  use Phoenix.Component

  import ZippikerWeb.CoreComponents

  @doc "Status of a workspace's subscription."
  attr :status, :atom, required: true

  def subscription_status(assigns) do
    {label, color} =
      case assigns.status do
        :trialing -> {"Trial", :blue}
        :active -> {"Active", :emerald}
        :past_due -> {"Past due", :rose}
        :canceled -> {"Canceled", :slate}
      end

    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <.badge color={@color}>{@label}</.badge>
    """
  end

  @doc "Status of a platform (Zippiker) invoice."
  attr :status, :atom, required: true

  def billing_status(assigns) do
    {label, color} =
      case assigns.status do
        :open -> {"Open", :amber}
        :paid -> {"Paid", :emerald}
        :void -> {"Void", :slate}
      end

    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <.badge color={@color}>{@label}</.badge>
    """
  end
end
