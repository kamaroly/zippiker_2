defmodule ZippikerWeb.LogoController do
  @moduledoc """
  Serves a legal entity's logo to people who can see its workspace:
  members, portal users of that workspace and super admins.
  """
  use ZippikerWeb, :controller

  @types %{
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".webp" => "image/webp"
  }

  def show(conn, %{"organization_id" => organization_id, "id" => id}) do
    with %{} = user <- conn.assigns[:current_user],
         {:ok, organization} <-
           Ash.get(Zippiker.Accounts.Organization, organization_id, actor: user),
         {:ok, %{logo_path: path}} when is_binary(path) <-
           Zippiker.Accounts.get_legal_entity(id, tenant: organization, authorize?: false),
         full = ZippikerWeb.Uploads.full_path(path),
         true <- File.exists?(full),
         {:ok, type} <- Map.fetch(@types, String.downcase(Path.extname(path))) do
      conn
      |> put_resp_content_type(type, nil)
      |> put_resp_header("cache-control", "private, max-age=86400")
      |> put_resp_header("x-content-type-options", "nosniff")
      |> send_file(200, full)
    else
      _ -> conn |> put_status(:not_found) |> text("Not found")
    end
  end
end
