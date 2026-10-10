defmodule ZippikerWeb.HelpLive do
  @moduledoc "The help center: article index with search, and article pages."
  use ZippikerWeb, :live_view

  alias ZippikerWeb.HelpArticles

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", articles: HelpArticles.articles())}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    case HelpArticles.find(slug) do
      nil ->
        {:noreply,
         socket |> put_flash(:error, "Article not found") |> push_navigate(to: ~p"/help")}

      article ->
        {previous, next} = neighbours(article)

        {:noreply,
         assign(socket,
           article: article,
           previous: previous,
           next: next,
           page_title: article.title
         )}
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, article: nil, page_title: "Help center")}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    term = query |> String.trim() |> String.downcase()

    articles =
      Enum.filter(HelpArticles.articles(), fn article ->
        term == "" or
          String.contains?(String.downcase(article.title <> " " <> article.summary), term)
      end)

    {:noreply, assign(socket, query: query, articles: articles)}
  end

  defp neighbours(article) do
    articles = HelpArticles.articles()
    index = Enum.find_index(articles, &(&1.slug == article.slug))
    {index > 0 && Enum.at(articles, index - 1), Enum.at(articles, index + 1)}
  end
end
