defmodule ChatWeb.ChatChannel do
  alias ChatWeb.Presence

  use ChatWeb, :channel

  @impl true
  def join("chat:lobby", payload, socket) do
    if authorized?(payload) do
      send(self(), "after_join")
      {:ok, socket |> assign(users: %{})}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info("after_join", socket) do
    Presence.track(self(), "after_join", socket.id, %{})

    [data] =
      Presence.list("after_join")
      |> Enum.map(fn {_, data} -> data[:metas] end)

    push(socket, "orang", %{data: data})

    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("chat:newUser", %{"user" => newUser}, %{assigns: %{users: users}} = socket) do
    Presence.update(self(), "after_join", socket.id, %{
      id: inspect(socket.channel_pid),
      user: newUser
    })

    updated_users = Map.put(users, inspect(socket.channel_pid), newUser) |> IO.inspect()

    %{"" => %{metas: list_user}} = Presence.list("after_join")
    list_user |> IO.inspect()

    broadcast(socket, "chat:newUser", %{newUser: newUser})
    broadcast(socket, "chat:userJoined", %{user: newUser})
    {:noreply, socket |> assign(users: updated_users)}
  end

  def handle_in("chat:msg", payload, socket) do
    broadcast(socket, "chat:msg", payload)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, %{assigns: %{users: users}} = socket) do
    user_name = Map.get(users, inspect(socket.channel_pid))
    broadcast(socket, "chat:userLeft", %{user: user_name})
    :ok
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
