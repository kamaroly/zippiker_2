defmodule ZippikerWeb.LiveHelpers do
  @moduledoc "Small helpers shared by workspace LiveViews."

  @doc "Actor and tenant options for every Ash call made on behalf of the user."
  def ash_opts(%Phoenix.LiveView.Socket{assigns: assigns}), do: ash_opts(assigns)

  def ash_opts(%{current_user: user, current_organization: organization}),
    do: [actor: user, tenant: organization]

  def admin?(%{current_role: role}), do: role in [:owner, :admin]
  def admin?(_assigns), do: false

  @doc "Whether the current workspace has a business module switched on."
  def module?(%{current_organization: organization}, key),
    do: ZippikerWeb.Modules.enabled?(organization, key)

  @doc "A Decimal in the workspace currency, always with cents (for accounting)."
  def amount(nil, _currency), do: "—"

  def amount(%Decimal{} = value, currency),
    do: Money.to_string!(Money.new!(currency, value), fractional_digits: 2)

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
