defmodule Web.Admin.ChannelController do
  use Web.AdminController

  alias Web.Channel

  def index(conn, _params) do
    channels = Channel.all()
    conn |> render("index.html", channels: channels)
  end

  def new(conn, _params) do
    changeset = Channel.new()
    conn |> render("new.html", changeset: changeset)
  end

  def create(conn, %{"channel" => params}) do
    case Channel.create(params) do
      {:ok, _channel} ->
        conn |> redirect(to: channel_path(conn, :index))

      {:error, changeset} ->
        conn |> render("new.html", changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    channel = Channel.get(id)
    changeset = Channel.edit(channel)
    conn |> render("edit.html", channel: channel, changeset: changeset)
  end

  def update(conn, %{"id" => id, "channel" => params}) do
    channel = Channel.get(id)

    case Channel.update(channel, params) do
      {:ok, _channel} ->
        conn |> redirect(to: channel_path(conn, :index))

      {:error, changeset} ->
        conn |> render("edit.html", channel: channel, changeset: changeset)
    end
  end
end
