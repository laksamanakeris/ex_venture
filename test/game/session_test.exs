defmodule Game.SessionTest do
  use GenServerCase
  use Data.ModelCase

  alias Data.Mail
  alias Game.Command
  alias Game.Message
  alias Game.Session
  alias Game.Session.Process
  alias Game.Session.State

  @socket Test.Networking.Socket
  @room Test.Game.Room
  @zone Test.Game.Zone

  setup do
    socket = :socket
    @socket.clear_messages()
    @room.clear_notifies()

    user = %{id: 1, name: "user", save: base_save()}
    {:ok, %{socket: socket, user: user, save: user.save}}
  end

  test "echoing messages", state = %{socket: socket} do
    {:noreply, ^state} = Process.handle_cast({:echo, "a message"}, state)

    assert @socket.get_echos() == [{socket, "a message"}]
  end

  describe "regenerating" do
    setup do
      stats = %{health_points: 10, max_health_points: 15, skill_points: 9, max_skill_points: 12, move_points: 8, max_move_points: 10}
      class = %{regen_health_points: 1, regen_skill_points: 1}
      %{user: %{class: class}, save: %{room_id: 1, level: 2, stats: stats}, regen: %{is_regenerating: true, count: 5}}
    end

    test "regens stats", state do
      @room.clear_update_characters()

      {:noreply, %{regen: %{count: 0}, save: %{stats: stats}}} = Process.handle_info(:regen, state)

      assert stats.health_points == 12
      assert stats.skill_points == 11
      assert stats.move_points == 9

      assert_received {:"$gen_cast", {:echo, ~s(You regenerated some health and skill points.)}}

      assert @room.get_update_characters() |> length() == 2
    end

    test "does not echo if stats did not change", state do
      stats = %{health_points: 15, max_health_points: 15, skill_points: 12, max_skill_points: 12, move_points: 10, max_move_points: 10}
      save = %{room_id: 1, level: 2, stats: stats}

      {:noreply, %{save: %{stats: stats}}} = Process.handle_info(:regen, %{state | save: save})

      assert stats.health_points == 15
      assert stats.skill_points == 12
      assert stats.move_points == 10

      refute_received {:"$gen_cast", {:echo, ~s(You regenerated some health and skill points.)}}
    end

    test "does not regen, only increments count if not high enough", state do
      {:noreply, %{regen: %{count: 2}, save: %{stats: stats}}} = Process.handle_info(:regen, %{state | regen: %{is_regenerating: true, count: 1}})

      assert stats.health_points == 10
      assert stats.skill_points == 9
    end
  end

  test "recv'ing messages - the first", %{socket: socket} do
    {:noreply, state} = Process.handle_cast({:recv, "name"}, %{socket: socket, state: "login"})

    assert @socket.get_prompts() == [{socket, "Password: "}]
    assert state.last_recv
  end

  test "recv'ing messages - after login processes commands", %{socket: socket} do
    user = create_user(%{name: "user", password: "password"})
    |> Repo.preload([class: [:skills]])

    state = %State{socket: socket, state: "active", mode: "commands", user: user, save: %{room_id: 1, stats: %{}}}
    {:noreply, state} = Process.handle_cast({:recv, "quit"}, state)

    assert @socket.get_echos() == [{socket, "Good bye."}]
    assert state.last_recv
  after
    Session.Registry.unregister()
  end

  test "processing a command that has continued commands", %{socket: socket} do
    user = create_user(%{name: "user", password: "password"})
    |> Repo.preload([class: [:skills]])

    @room.set_room(%Data.Room{id: 1, name: "", description: "", exits: [%{north_id: 2, south_id: 1}], players: [], shops: []})
    state = %State{socket: socket, state: "active", mode: "commands", user: user, save: %{room_id: 1, stats: %{base_stats() | move_points: 10}}, regen: %{is_regenerating: false}}
    {:noreply, state} = Process.handle_cast({:recv, "run 2n"}, state)

    assert state.mode == "continuing"
    assert_receive {:continue, %Command{module: Command.Run, args: {[:north]}}}
  after
    Session.Registry.unregister()
  end

  test "continuing with processed commands", %{socket: socket} do
    user = create_user(%{name: "user", password: "password"})
    |> Repo.preload([class: [:skills]])

    @room.set_room(%Data.Room{id: 1, name: "", description: "", exits: [%{north_id: 2, south_id: 1}], players: [], shops: []})
    state = %State{socket: socket, state: "active", mode: "continuing", user: user, save: %{room_id: 1, stats: %{base_stats() | move_points: 10}}, regen: %{is_regenerating: false}}
    command = %Command{module: Command.Run, args: {[:north, :north]}}
    {:noreply, _state} = Process.handle_info({:continue, command}, state)

    assert_receive {:continue, %Command{module: Command.Run, args: {[:north]}}}
  after
    Session.Registry.unregister()
  end

  test "does not process commands while mode is continuing", %{socket: socket} do
    user = create_user(%{name: "user", password: "password"})
    |> Repo.preload([class: [:skills]])

    state = %{socket: socket, state: "active", mode: "continuing", user: user, save: %{room_id: 1}}
    {:noreply, state} = Process.handle_cast({:recv, "say Hello"}, state)

    assert state.mode == "continuing"
    assert @socket.get_echos() == []
  after
    Session.Registry.unregister()
  end

  test "user is not signed in yet does not save" do
    assert {:noreply, %{}} = Process.handle_info(:save, %{})
  end

  test "save the user's save" do
    user = create_user(%{name: "player", password: "password"})
    save = %{user.save | stats: %{user.save.stats | health_points: 10}}

    {:noreply, _state} = Process.handle_info(:save, %{state: "active", user: user, save: save, session_started_at: Timex.now()})

    user = Data.User |> Data.Repo.get(user.id)
    assert user.save.stats.health_points == 10
  end

  test "checking for inactive players - not inactive", %{socket: socket} do
    {:noreply, _state} = Process.handle_info(:inactive_check, %{socket: socket, last_recv: Timex.now()})

    assert @socket.get_disconnects() == []
  end

  test "checking for inactive players - inactive", %{socket: socket, user: user, save: save} do
    state = %{
      socket: socket,
      user: user,
      save: save,
      is_afk: false,
      last_recv: Timex.now() |> Timex.shift(minutes: -66),
    }

    {:noreply, state} = Process.handle_info(:inactive_check, state)

    assert state.is_afk
  after
    Session.Registry.unregister()
  end

  describe "disconnects" do
    test "unregisters the pid when disconnected" do
      user = %Data.User{name: "user", seconds_online: 0}
      Session.Registry.register(user)

      state = %{state: "active", user: user, save: %{room_id: 1}, session_started_at: Timex.now(), stats: %{}}
      {:stop, :normal, _state} = Process.handle_cast(:disconnect, state)
      assert Session.Registry.connected_players == []
    after
      Session.Registry.unregister()
    end

    test "adds the time played" do
      user = create_user(%{name: "user", password: "password"})
      state = %{state: "active", user: user, save: user.save, session_started_at: Timex.now() |> Timex.shift(hours: -3), stats: %{}}

      {:stop, :normal, _state} = Process.handle_cast(:disconnect, state)

      user = Repo.get(Data.User, user.id)
      assert user.seconds_online == 10800
    end
  end

  test "applying effects", %{socket: socket} do
    @room.clear_update_characters()

    effect = %{kind: "damage", type: :slashing, amount: 10}
    stats = %{health_points: 25}
    user = %{id: 2, name: "user", class: class_attributes(%{})}

    state = %State{socket: socket, state: "active", mode: "commands", user: user, save: %{room_id: 1, stats: stats}, is_targeting: MapSet.new}
    {:noreply, state} = Process.handle_cast({:apply_effects, [effect], {:npc, %{id: 1, name: "Bandit"}}, "description"}, state)
    assert state.save.stats.health_points == 15

    assert_received {:"$gen_cast", {:echo, ~s(description\n10 slashing damage is dealt.)}}

    assert [{1, {:user,  %{name: "user", save: %{room_id: 1, stats: %{health_points: 15}}}}}] = @room.get_update_characters()
  end

  test "applying effects with continuous effects", %{socket: socket} do
    @room.clear_update_characters()

    effect = %{kind: "damage/over-time", type: :slashing, every: 10, count: 3, amount: 10}
    stats = %{health_points: 25}
    user = %{id: 2, name: "user", class: class_attributes(%{})}
    from = {:npc, %{id: 1, name: "Bandit"}}
    state = %State{socket: socket, state: "active", mode: "commands", user: user, save: %{room_id: 1, stats: stats}, is_targeting: MapSet.new()}

    {:noreply, state} = Process.handle_cast({:apply_effects, [effect], from, "description"}, state)

    assert state.save.stats.health_points == 15
    assert_received {:"$gen_cast", {:echo, ~s(description\n10 slashing damage is dealt.)}}

    [{^from, effect}] = state.continuous_effects
    assert effect.kind == "damage/over-time"
    assert effect.id

    effect_id = effect.id
    assert_receive {:continuous_effect, ^effect_id}
  end

  test "applying effects - died", %{socket: socket} do
    Session.Registry.register(%{id: 2})

    effect = %{kind: "damage", type: :slashing, amount: 10}
    stats = %{health_points: 5}
    user = %{id: 2, name: "user", class: class_attributes(%{})}

    state = %State{socket: socket, state: "active", mode: "commands", user: user, save: %{room_id: 1, stats: stats}}
    {:noreply, state} = Process.handle_cast({:apply_effects, [effect], {:npc, %{id: 1, name: "Bandit"}}, "description"}, state)
    assert state.save.stats.health_points == -5

    assert_received {:"$gen_cast", {:echo, ~s(description\n10 slashing damage is dealt.)}}
    assert [{1, {"character/died", _, _, _}}] = @room.get_notifies()
  after
    Session.Registry.unregister()
  end

  test "applying effects - died with zone graveyard", %{socket: socket} do
    Session.Registry.register(%{id: 2})

    @room.set_room(@room._room())
    @zone.set_zone(Map.put(@zone._zone(), :graveyard_id, 2))

    effect = %{kind: "damage", type: :slashing, amount: 10}
    stats = %{health_points: 5}
    user = %{id: 2, name: "user", class: class_attributes(%{})}
    save = %{room_id: 1, stats: stats}

    state = %State{socket: socket, state: "active", mode: "commands", user: user, save: save, is_targeting: MapSet.new()}
    {:noreply, state} = Process.handle_cast({:apply_effects, [effect], {:npc, %{id: 1, name: "Bandit"}}, "description"}, state)

    assert state.save.stats.health_points == -5

    assert_receive {:resurrect, 2}
  after
    Session.Registry.unregister()
  end

  test "applying effects - died with no zone graveyard", %{socket: socket} do
    Session.Registry.register(%{id: 2})

    @room.set_room(@room._room())
    @zone.set_zone(Map.put(@zone._zone(), :graveyard_id, nil))
    @zone.set_graveyard({:error, :no_graveyard})

    effect = %{kind: "damage", type: :slashing, amount: 10}
    stats = %{health_points: 5}
    user = %{id: 2, name: "user", class: class_attributes(%{})}
    save = %{room_id: 1, stats: stats}

    state = %State{socket: socket, state: "active", mode: "commands", user: user, save: save, is_targeting: MapSet.new()}
    {:noreply, state} = Process.handle_cast({:apply_effects, [effect], {:npc, %{id: 1, name: "Bandit"}}, "description"}, state)

    assert state.save.stats.health_points == -5

    refute_receive {:"$gen_cast", {:teleport, _}}
  after
    Session.Registry.unregister()
  end

  describe "targeted" do
    test "being targeted tracks the targeter", %{socket: socket, user: user} do
      targeter = {:user, %{id: 10, name: "Player"}}

      {:noreply, state} = Process.handle_cast({:targeted, targeter}, %{socket: socket, user: user, target: nil, is_targeting: MapSet.new})

      assert state.is_targeting |> MapSet.size() == 1
      assert state.is_targeting |> MapSet.member?({:user, 10})
    end

    test "if your target is empty, set to the targeter", %{socket: socket, user: user} do
      targeter = {:user, %{id: 10, name: "Player"}}

      {:noreply, state} = Process.handle_cast({:targeted, targeter}, %{socket: socket, user: user, target: nil, is_targeting: MapSet.new})

      assert state.target == {:user, 10}
    end
  end

  describe "channels" do
    setup do
      @socket.clear_messages()

      %{from: %{id: 10, name: "Player"}}
    end

    test "receiving a tell", %{socket: socket, from: from} do
      message = Message.tell(from, "howdy")

      {:noreply, state} = Process.handle_info({:channel, {:tell, {:user, from}, message}}, %{socket: socket})

      [{^socket, tell}] = @socket.get_echos()
      assert Regex.match?(~r/howdy/, tell)
      assert state.reply_to == {:user, from}
    end

    test "receiving a join" do
      save = %{channels: ["newbie"]}
      state = %{user: %{save: save}, save: save}

      {:noreply, state} = Process.handle_info({:channel, {:joined, "global"}}, state)
      assert state.save.channels == ["global", "newbie"]
    end

    test "does not duplicate channels list" do
      save = %{channels: ["newbie"]}
      state = %{user: %{save: save}, save: save}

      {:noreply, state} = Process.handle_info({:channel, {:joined, "newbie"}}, state)
      assert state.save.channels == ["newbie"]
    end

    test "receiving a leave" do
      save = %{channels: ["global", "newbie"]}
      state = %{user: %{save: save}, save: save}

      {:noreply, state} = Process.handle_info({:channel, {:left, "global"}}, state)
      assert state.save.channels == ["newbie"]
    end
  end

  describe "teleport" do
    setup do
      user = create_user(%{name: "user", password: "password"})
      |> Repo.preload([:race, :class])
      zone = create_zone()
      room = create_room(zone)

      %{user: user, room: room}
    end

    test "teleports the user", %{socket: socket, user: user, room: room} do
      {:noreply, state} = Process.handle_cast({:teleport, room.id}, %{socket: socket, user: user, save: user.save})
      assert state.save.room_id == room.id
    end
  end

  describe "resurrection" do
    setup do
      @room.clear_enters()
      @room.clear_leaves()
    end

    test "sets health_points to 1 if < 0", state do
      save = %{stats: %{health_points: -1}, room_id: 2}
      state = %{state | save: save}

      {:noreply, state} = Process.handle_info({:resurrect, 2}, state)

      assert state.save.stats.health_points == 1
      assert state.user.save.stats.health_points == 1
    end

    test "leaves old room, enters new room", state do
      save = %{stats: %{health_points: -1}, room_id: 1}
      state = %{state | save: save}

      {:noreply, _state} = Process.handle_info({:resurrect, 2}, state)

      [{1, {:user, _}, :death}] = @room.get_leaves()
      [{2, {:user, _}, :respawn}] = @room.get_enters()
    end

    test "does not touch health_points if > 0", state do
      save = %{stats: %{health_points: 2}}
      state = %{state | save: save}

      {:noreply, state} = Process.handle_info({:resurrect, 2}, state)

      assert state.save.stats.health_points == 2
    end
  end

  describe "event notification" do
    test "player enters the room", state do
      {:noreply, ^state} = Process.handle_cast({:notify, {"room/entered", {{:user, %{id: 1, name: "Player"}}, {:enter, :south}}}}, state)
      [{_, "{player}Player{/player} enters from the {command}south{/command}."}] = @socket.get_echos()
    end

    test "npc enters the room", state do
      {:noreply, ^state} = Process.handle_cast({:notify, {"room/entered", {{:npc, %{id: 1, name: "Bandit"}}, {:enter, :south}}}}, state)
      [{_, "{npc}Bandit{/npc} enters from the {command}south{/command}."}] = @socket.get_echos()
    end

    test "player leaves the room", state do
      {:noreply, ^state} = Process.handle_cast({:notify, {"room/leave", {{:user, %{id: 1, name: "Player"}}, {:leave, :north}}}}, state)
      [{_, "{player}Player{/player} leaves heading {command}north{/command}."}] = @socket.get_echos()
    end

    test "npc leaves the room", state do
      {:noreply, ^state} = Process.handle_cast({:notify, {"room/leave", {{:npc, %{id: 1, name: "Bandit"}}, {:leave, :north}}}}, state)
      [{_, "{npc}Bandit{/npc} leaves heading {command}north{/command}."}] = @socket.get_echos()
    end

    test "player leaves the room and they were the target", %{socket: socket} do
      state = %{target: {:user, 1}, socket: socket}
      {:noreply, state} = Process.handle_cast({:notify, {"room/leave", {{:user, %{id: 1, name: "Player"}}, {:leave, :north}}}}, state)
      assert is_nil(state.target)
    end

    test "npc leaves the room and they were the target", %{socket: socket} do
      state = %{target: {:npc, 1}, socket: socket}
      {:noreply, state} = Process.handle_cast({:notify, {"room/leave", {{:npc, %{id: 1, name: "Bandit"}}, {:leave, :north}}}}, state)
      assert is_nil(state.target)
    end

    test "room heard", state do
      {:noreply, ^state} = Process.handle_cast({:notify, {"room/heard", Message.say(%{id: 1, name: "Player"}, "hi")}}, state)

      [{_socket, echo}] = @socket.get_echos()
      assert Regex.match?(~r(hi), echo)
    end

    test "room overheard - echos if user is not in the list of characters", state do
      {:noreply, ^state} = Process.handle_cast({:notify, {"room/overheard", [], "hi"}}, state)

      [{_socket, echo}] = @socket.get_echos()
      assert Regex.match?(~r(hi), echo)
    end

    test "room overheard - does not echo if user is in the list of characters", state do
      {:noreply, ^state} = Process.handle_cast({:notify, {"room/overheard", [{:user, state.user}], "hi"}}, state)

      assert [] = @socket.get_echos()
    end

    test "new mail received", state do
      mail = %Mail{id: 1, sender: %{id: 10, name: "Player"}}

      {:noreply, ^state} = Process.handle_cast({:notify, {"mail/new", mail}}, state)

      [{_socket, echo}] = @socket.get_echos()
      assert Regex.match?(~r(New mail)i, echo)
    end

    test "character died", state do
      npc = {:npc, %{id: 1, name: "bandit"}}

      {:noreply, ^state} = Process.handle_cast({:notify, {"character/died", npc, :character, npc}}, state)

      [{_socket, echo}] = @socket.get_echos()
      assert Regex.match?(~r(has died), echo)
    end

    test "new item received", state do
      start_and_clear_items()
      insert_item(%{id: 1, name: "Potion"})
      instance = item_instance(1)

      state = %{state | user: %{save: nil}, save: %{items: []}}

      {:noreply, state} = Process.handle_cast({:notify, {"item/receive", {:npc, %{name: "Guard"}}, instance}}, state)

      assert state.save.items == [instance]

      [{_socket, echo}] = @socket.get_echos()
      assert Regex.match?(~r(Potion)i, echo)
      assert Regex.match?(~r(Guard)i, echo)
    end

    test "new currency received", state do
      state = %{state | user: %{save: nil}, save: %{currency: 10}}

      {:noreply, state} = Process.handle_cast({:notify, {"currency/receive", {:npc, %{name: "Guard"}}, 50}}, state)

      assert state.save.currency == 60

      [{_socket, echo}] = @socket.get_echos()
      assert Regex.match?(~r(50 gold)i, echo)
      assert Regex.match?(~r(Guard)i, echo)
    end
  end

  describe "character dying" do
    setup %{socket: socket} do
      target = {:user, %{id: 10, name: "Player"}}
      user = %{id: 10, class: class_attributes(%{})}

      state = %{
        socket: socket,
        state: "active",
        user: user,
        save: base_save(),
        target: {:user, 10},
        is_targeting: MapSet.new(),
      }

      %{state: state, target: target}
    end

    test "clears your target", %{state: state, target: target} do
      {:noreply, state} = Process.handle_cast({:notify, {"character/died", target, :character, {:user, state.user}}}, state)

      assert is_nil(state.target)
    end

    test "npc - a died message is sent and experience is applied", %{state: state} do
      target = {:npc, %{id: 10, original_id: 1, name: "Bandit", level: 1, experience_points: 1200}}
      state = %{state | target: {:npc, 10}}

      {:noreply, state} = Process.handle_cast({:notify, {"character/died", target, :character, {:user, state.user}}}, state)

      assert is_nil(state.target)
      assert state.save.level == 2
    end
  end
end
