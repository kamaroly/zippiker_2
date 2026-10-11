defmodule ZippikerWeb.LiveHelpers do
  @moduledoc "Small helpers shared by workspace LiveViews."

  @doc "Actor and tenant options for every Ash call made on behalf of the user."
  def ash_opts(%Phoenix.LiveView.Socket{assigns: assigns}), do: ash_opts(assigns)

  def ash_opts(%{current_user: user, current_organization: organization}),
    do: [actor: user, tenant: organization]

  def admin?(%{current_role: role}), do: role in [:owner, :admin]
  def admin?(_assigns), do: false

  @doc """
  Whether the current user's roles include a permission (owners and admins
  have them all). See `Zippiker.Accounts.Permissions`.
  """
  def can?(%{current_permissions: permissions}, key),
    do: ZippikerWeb.Access.can?(permissions, key)

  def can?(assigns, _key), do: admin?(assigns)

  @doc """
  Whether the current user may impersonate a workspace member: owners can
  impersonate admins and members, admins only members. Never yourself, a
  super admin, or while already impersonating someone.
  """
  def can_impersonate?(%{current_user: actor} = assigns, %{role: role, user: user}) do
    is_nil(actor.__metadata__[:impersonator]) and user.id != actor.id and
      not user.super_admin? and impersonation_allowed?(assigns[:current_role], role)
  end

  def impersonation_allowed?(:owner, target_role), do: target_role in [:admin, :member]
  def impersonation_allowed?(:admin, target_role), do: target_role == :member
  def impersonation_allowed?(_role, _target_role), do: false

  @doc "Whether the current workspace has a business module switched on."
  def module?(%{current_organization: organization}, key),
    do: ZippikerWeb.Modules.enabled?(organization, key)

  @doc "A Decimal in the workspace currency, always with cents (for accounting)."
  def amount(nil, _currency), do: "—"

  def amount(%Decimal{} = value, currency),
    do: Money.to_string!(Money.new!(currency, value), fractional_digits: 2)

  @doc """
  The change request number when maker-checker held the change instead of
  applying it (from a failed form or an Ash error), else nil.
  """
  def change_requested(%Phoenix.HTML.Form{source: source}), do: change_requested(source)

  def change_requested(%AshPhoenix.Form{} = form) do
    form
    |> AshPhoenix.Form.raw_errors(for_path: :all)
    |> Map.values()
    |> List.flatten()
    |> Enum.find_value(&change_requested/1)
  end

  def change_requested(%Zippiker.Workflow.Errors.ChangeRequested{number: number}), do: number

  def change_requested(%{errors: errors}) when is_list(errors),
    do: Enum.find_value(errors, &change_requested/1)

  def change_requested(_error), do: nil

  @doc "Flash for a change held for a checker's approval."
  def change_requested_message(number),
    do: "Sent for approval as change request #{number}. It applies once a checker approves it."

  @doc "A short, human message from an Ash error (its first inner error)."
  def error_message(%{errors: [first | _]}), do: error_message(first)
  def error_message(%{message: message}) when is_binary(message), do: upcase_first(message)
  def error_message(error) when is_exception(error), do: Exception.message(error)
  def error_message(_error), do: "Something went wrong"

  defp upcase_first(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest

  @doc "Turns a plain amount form field into a Money map in the organization currency."
  def put_money(params, field, organization) do
    case Map.get(params, field) do
      value when is_binary(value) ->
        amount = String.replace(value, ",", "") |> String.trim()

        Map.put(
          params,
          field,
          if(amount == "",
            do: nil,
            else: %{"amount" => amount, "currency" => organization.currency}
          )
        )

      _ ->
        params
    end
  end

  @doc "Value for an amount input from a Money (or anything else)."
  def money_input(%Money{amount: amount}), do: Decimal.to_string(amount, :normal)
  def money_input(%{"amount" => amount}), do: amount
  def money_input(value), do: value

  @doc "`{name, id}` options of the organization's members, for owner/assignee selects."
  def member_options(assigns) do
    assigns.current_organization.id
    |> Zippiker.Accounts.list_members!(actor: assigns.current_user)
    |> Enum.map(&{ZippikerWeb.Format.user_name(&1.user), &1.user_id})
  end

  @doc "`{name, id}` options of the active branches when the team has several; [] otherwise."
  def branch_options(%{current_organization: %{multi_branch?: true}} = assigns) do
    assigns
    |> ash_opts()
    |> then(&Zippiker.Accounts.list_branches!(%{active_only?: true}, &1))
    |> Enum.map(&{"#{&1.name} (#{&1.code})", &1.id})
  end

  def branch_options(_assigns), do: []

  @doc "Comma separated tags -> list."
  def split_tags(params) do
    case params do
      %{"tags" => tags} when is_binary(tags) ->
        Map.put(
          params,
          "tags",
          tags |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        )

      params ->
        params
    end
  end

  @doc "Reads an integer page number from params."
  def page_param(params) do
    case Integer.parse(params["page"] || "1") do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  @doc """
  Builds `base?query` dropping blank values (and blank nested `cf` values),
  e.g. `query_path("/contacts", %{q: "", cf: %{"tier" => "Gold"}})`.
  """
  def query_path(base, params) do
    params =
      params
      |> Enum.map(fn
        {key, value} when is_map(value) ->
          {key, Map.reject(value, fn {_k, v} -> v in [nil, ""] end)}

        pair ->
          pair
      end)
      |> Enum.reject(fn {_key, value} -> value in [nil, "", 1, %{}] end)
      |> Map.new()

    if params == %{}, do: base, else: base <> "?" <> Plug.Conn.Query.encode(params)
  end

  @doc "Custom field definitions that can be used as list filters."
  def filterable_fields(entity, assigns) do
    entity
    |> Zippiker.Extensibility.list_custom_fields!(ash_opts(assigns))
    |> Enum.filter(&(&1.type in [:select, :multi_select, :boolean]))
  end

  @doc "Keeps only `cf` params whose key is a filterable definition."
  def parse_custom_filters(params, definitions) do
    keys = MapSet.new(definitions, & &1.key)

    case params["cf"] do
      %{} = cf -> cf |> Map.filter(fn {k, v} -> k in keys and is_binary(v) and v != "" end)
      _ -> %{}
    end
  end
end
