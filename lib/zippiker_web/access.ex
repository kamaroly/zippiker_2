defmodule ZippikerWeb.Access do
  @moduledoc """
  Which modules a member may open, from the `view.*` permissions of their
  roles. Self-service pages (my workspace, my leave, my time, my claims),
  approvals and settings are open to every member; each action on them is
  still checked by the resource policies.
  """

  alias Zippiker.Accounts.Permissions

  # Pages and LiveViews every member can open.
  @self_service_pages [:me, :my_tasks, :my_profile, :leave, :leave_claims, :time]

  @self_service_views [
    ZippikerWeb.MeLive.Overview,
    ZippikerWeb.MeLive.Tasks,
    ZippikerWeb.MeLive.Profile,
    ZippikerWeb.HRLive.Time,
    ZippikerWeb.LeaveLive.Index,
    ZippikerWeb.LeaveLive.Claims,
    ZippikerWeb.ChecklistLive.Show
  ]

  @doc "Permissions of a user in a workspace: `:all`, a MapSet, or nil."
  def permissions(user, organization) do
    Zippiker.Accounts.Checks.Membership.permissions_in(user, organization.id)
  end

  def can?(:all, _key), do: true
  def can?(%MapSet{} = granted, key), do: MapSet.member?(granted, key)
  def can?(_permissions, _key), do: false

  @doc "The view permission a sidebar page needs (`{key, label, path, module}`), or nil."
  def page_permission({key, _label, _path, module}) do
    cond do
      key in @self_service_pages -> nil
      key in [:contacts, :companies] -> "view.contacts"
      key == :report_center -> "view.reports"
      key == :assistant -> "assistant.use"
      true -> module_permission(module)
    end
  end

  @doc "The view permission a LiveView needs, or nil."
  def view_permission(view, action) do
    cond do
      view in @self_service_views ->
        nil

      view == ZippikerWeb.PartyLive.Index and action in [:customers, :new_customer] ->
        "view.sales"

      view == ZippikerWeb.PartyLive.Index and action in [:suppliers, :new_supplier] ->
        "view.purchasing"

      view in [ZippikerWeb.PartyLive.Index, ZippikerWeb.PartyLive.Show] ->
        "view.contacts"

      view in [ZippikerWeb.ReportLive.Index, ZippikerWeb.ReportLive.Show] ->
        "view.reports"

      true ->
        view |> ZippikerWeb.Modules.for_view(action) |> module_permission()
    end
  end

  @doc "The view permission of an app module (`:sales` -> \"view.sales\"), if there is one."
  def module_permission(nil), do: nil

  def module_permission(module) do
    key = "view.#{module}"
    if key in Permissions.views(), do: key
  end

  @doc "Reports a member can run (see `Zippiker.Reporting.Catalog.visible/2`)."
  def reports(organization, permissions),
    do: Zippiker.Reporting.Catalog.visible(organization, permissions)
end
