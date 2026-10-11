defmodule Zippiker.Assistant.Conversation.Actions.Turn do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Zippiker.Accounts.Checks.Membership
  alias Zippiker.Assistant.Engine

  @impl true
  def run(input, opts, context) do
    organization = Zippiker.Reporting.Context.organization(input.tenant)
    actor = context.actor

    ctx = %{
      actor: actor,
      organization: organization,
      permissions: Membership.permissions_in(actor, organization.id),
      role: role(actor, organization)
    }

    args = input.arguments

    result =
      case opts[:step] do
        :reply -> Engine.reply(args.history, args.text, ctx)
        :resolve -> Engine.resolve(args.history, args.pending, args.approved?, ctx)
      end

    case result do
      {:ok, map} ->
        {:ok, map}

      {:error, :not_configured} ->
        {:ok, %{status: "not_configured", history: args.history, pending: nil}}

      {:error, message} ->
        {:ok, %{status: "error", error: message, history: args.history, pending: nil}}
    end
  end

  defp role(actor, organization) do
    Enum.find_value(actor.memberships || [], "member", fn membership ->
      membership.organization_id == organization.id && to_string(membership.role)
    end)
  rescue
    _ -> "member"
  end
end
