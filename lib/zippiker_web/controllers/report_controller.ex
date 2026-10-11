defmodule ZippikerWeb.ReportController do
  @moduledoc "CSV export of a standard report, with the same filters as the report page."
  use ZippikerWeb, :controller

  alias Zippiker.Reporting.Catalog
  alias ZippikerWeb.ReportParams

  def export(conn, %{"key" => key} = params) do
    with %{} = user <- conn.assigns[:current_user],
         {organization, _role} <-
           ZippikerWeb.LiveUserAuth.current_workspace(user, get_session(conn, :organization_id)),
         %{} = definition <- Enum.find(Catalog.available(organization), &(&1.key == key)) do
      opts = [actor: user, tenant: organization]
      branch_ids = branch_ids(organization, opts)
      selection = ReportParams.parse(params, definition.period, branch_ids)

      report =
        Zippiker.Reporting.run_report!(
          key,
          %{from: selection.from, to: selection.to, branch_id: selection.branch_id},
          opts
        )

      send_download(conn, {:binary, ZippikerWeb.ReportComponents.to_csv(report)},
        filename: "#{key}-#{selection.to}.csv",
        content_type: "text/csv"
      )
    else
      _ -> conn |> put_status(:not_found) |> text("Not found")
    end
  end

  defp branch_ids(%{multi_branch?: true}, opts),
    do: Enum.map(Zippiker.Accounts.list_branches!(opts), & &1.id)

  defp branch_ids(_organization, _opts), do: []
end
