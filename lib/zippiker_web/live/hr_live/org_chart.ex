defmodule ZippikerWeb.HRLive.OrgChart do
  @moduledoc "Who reports to whom, drawn as a tree from the top."
  use ZippikerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Org chart",
       tree: Zippiker.HR.org_chart!(ash_opts(socket))
     )}
  end
end
