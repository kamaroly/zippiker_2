defmodule ZippikerWeb.PageHTML do
  @moduledoc "Templates for the public pages (the landing page)."
  use ZippikerWeb, :html

  embed_templates "page_html/*"

  @doc "A plan's monthly price per user, e.g. \"$12\" or \"Free\"."
  def plan_price(plan) do
    if Decimal.eq?(plan.price_per_seat, 0),
      do: "Free",
      else: Format.money(Money.new!(plan.currency, plan.price_per_seat))
  end

  def module_name(key), do: ZippikerWeb.Modules.name(key) || Format.humanize(key)
end
