defmodule ZippikerWeb.LeaveAttachmentController do
  @moduledoc "Downloads a leave request's supporting document for members of its workspace."
  use ZippikerWeb, :controller

  def show(conn, %{"id" => id}) do
    with %{} = user <- conn.assigns[:current_user],
         {organization, _role} <-
           ZippikerWeb.LiveUserAuth.current_workspace(user, get_session(conn, :organization_id)),
         {:ok, %{attachment_path: path} = request} when is_binary(path) <-
           Zippiker.HR.get_leave_request(id, actor: user, tenant: organization),
         full = ZippikerWeb.Uploads.full_path(path),
         true <- File.exists?(full) do
      send_download(conn, {:file, full}, filename: request.attachment_name, disposition: :inline)
    else
      _ -> conn |> put_status(:not_found) |> text("Not found")
    end
  end
end
