defmodule ZippikerWeb.PageController do
  @moduledoc """
  The public home page at `/`. Signed-in people go straight to their
  dashboard; visitors get the landing page, with pricing from the
  platform's active plans.
  """
  use ZippikerWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/dashboard")
    else
      plans =
        case Zippiker.Platform.list_plans(%{active_only?: true}, authorize?: false) do
          {:ok, plans} -> plans
          _ -> []
        end

      conn
      |> assign(:page_title, "The AI-native ERP for growing businesses")
      |> assign(:plans, plans)
      |> render(:home, layout: false)
    end
  end
end
