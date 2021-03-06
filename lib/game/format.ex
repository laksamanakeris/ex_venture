defmodule Game.Format do
  @moduledoc """
  Format data into strings to send to the connected player
  """

  use Game.Currency

  alias Data.Exit
  alias Data.Item
  alias Data.Mail
  alias Data.Room
  alias Data.User
  alias Data.Save
  alias Data.Skill
  alias Game.Color
  alias Game.Door
  alias Game.Format.Table
  alias Game.Quest

  @doc """
  Template a string

      iex> Game.Format.template("[name] says hello", %{name: "Player"})
      "Player says hello"
  """
  def template(string, map) do
    map
    |> Enum.reduce(string, fn {key, val}, string ->
      String.replace(string, "[#{key}]", to_string(val))
    end)
  end

  @doc """
  Format a channel message

  Example:

      iex> Game.Format.channel_say(%{name: "global", color: "red"}, {:npc, %{name: "NPC"}}, "Hello")
      ~s({red}[global]{/red} {npc}NPC{/npc} says, {say}"Hello"{/say})
  """
  @spec channel_say(String.t(), Character.t(), String.t()) :: String.t()
  def channel_say(channel, sender, message) do
    ~s({#{channel.color}}[#{channel.name}]{/#{channel.color}} #{say(sender, message)})
  end

  @doc """
  Format the user's prompt

  Example:

      iex> stats = %{health_points: 50, max_health_points: 75, skill_points: 9, max_skill_points: 10, move_points: 4, max_move_points: 10}
      ...> config = %{prompt: "%h/%Hhp %s/%Ssp %m/%Mmv %xxp"}
      ...> Game.Format.prompt(%{name: "user"}, %{experience_points: 1010, stats: stats, config: config})
      "[50/75hp 9/10sp 4/10mv 10xp] > "
  """
  @spec prompt(User.t(), Save.t()) :: String.t()
  def prompt(user, save)

  def prompt(_user, %{experience_points: exp, stats: stats, config: config}) do
    exp = rem(exp, 1000)

    "[#{config.prompt}] > "
    |> String.replace("%h", to_string(stats.health_points))
    |> String.replace("%H", to_string(stats.max_health_points))
    |> String.replace("%s", to_string(stats.skill_points))
    |> String.replace("%S", to_string(stats.max_skill_points))
    |> String.replace("%m", to_string(stats.move_points))
    |> String.replace("%M", to_string(stats.max_move_points))
    |> String.replace("%x", to_string(exp))
  end

  def prompt(_user, _save), do: "> "

  @doc """
  Format a say message

  Example:

      iex> Game.Format.say(:you, "Hello")
      ~s[You say, {say}"Hello"{/say}]

      iex> Game.Format.say({:npc, %{name: "NPC"}}, "Hello")
      ~s[{npc}NPC{/npc} says, {say}"Hello"{/say}]

      iex> Game.Format.say({:user, %{name: "Player"}}, "Hello")
      ~s[{player}Player{/player} says, {say}"Hello"{/say}]
  """
  @spec say(Character.t(), String.t()) :: String.t()
  def say(:you, message) do
    ~s[You say, {say}"#{message}"{/say}]
  end
  def say(character, message) do
    ~s[#{name(character)} says, {say}"#{message}"{/say}]
  end

  @doc """
  Format a say to message

  Example:

      iex> Game.Format.say_to(:you, {:user, %{name: "Player"}}, "Hello")
      ~s[You say to {player}Player{/player}, {say}"Hello"{/say}]

      iex> Game.Format.say_to({:npc, %{name: "NPC"}}, {:user, %{name: "Player"}}, "Hello")
      ~s[{npc}NPC{/npc} says to {player}Player{/player}, {say}"Hello"{/say}]

      iex> Game.Format.say_to({:user, %{name: "Player"}}, {:npc, %{name: "Guard"}}, "Hello")
      ~s[{player}Player{/player} says to {npc}Guard{/npc}, {say}"Hello"{/say}]
  """
  @spec say_to(Character.t(), Character.t(), String.t()) :: String.t()
  def say_to(:you, sayee, message) do
    ~s[You say to #{name(sayee)}, {say}"#{message}"{/say}]
  end
  def say_to(sayer, sayee, message) do
    ~s[#{name(sayer)} says to #{name(sayee)}, {say}"#{message}"{/say}]
  end

  @doc """
  Format a tell message

      iex> Game.Format.tell({:user, %{name: "Player"}}, "secret message")
      ~s[{player}Player{/player} tells you, {say}"secret message"{/say}]
  """
  @spec tell(Character.t(), String.t()) :: String.t()
  def tell(sender, message) do
    ~s[#{name(sender)} tells you, {say}"#{message}"{/say}]
  end

  @doc """
  Format a tell message, for display of the sender

      iex> Game.Format.send_tell({:user, %{name: "Player"}}, "secret message")
      ~s[You tell {player}Player{/player}, {say}"secret message"{/say}]
  """
  @spec send_tell(Character.t(), String.t()) :: String.t()
  def send_tell(character, message) do
    ~s[You tell #{name(character)}, {say}"#{message}"{/say}]
  end

  @doc """
  Format an emote message

  Example:

      iex> Game.Format.emote({:npc, %{name: "NPC"}}, "does something")
      ~s[{npc}NPC{/npc} {say}does something{/say}]

      iex> Game.Format.emote({:user, %{name: "Player"}}, "does something")
      ~s[{player}Player{/player} {say}does something{/say}]
  """
  @spec emote(Character.t(), String.t()) :: String.t()
  def emote(character, emote) do
    ~s[#{name(character)} {say}#{emote}{/say}]
  end

  @doc """
  Format a whisper message

      iex> Game.Format.whisper({:user, %{name: "Player"}}, "secret message")
      ~s[{player}Player{/player} whispers to you, {say}"secret message"{/say}]
  """
  @spec whisper(Character.t(), String.t()) :: String.t()
  def whisper(sender, message) do
    ~s[#{name(sender)} whispers to you, {say}"#{message}"{/say}]
  end

  @doc """
  Format a whisper message from the user

      iex> Game.Format.send_whisper({:user, %{name: "Player"}}, "secret message")
      ~s[You whisper to {player}Player{/player}, {say}"secret message"{/say}]
  """
  @spec send_whisper(Character.t(), String.t()) :: String.t()
  def send_whisper(receiver, message) do
    ~s[You whisper to #{name(receiver)}, {say}"#{message}"{/say}]
  end

  @doc """
  Format a whisper overheard message for others in the room

      iex> Game.Format.whisper_overheard({:user, %{name: "Player"}}, {:npc, %{name: "Guard"}})
      ~s[You overhear {player}Player{/player} whispering to {npc}Guard{/npc}.]
  """
  @spec whisper_overheard(Character.t(), String.t()) :: String.t()
  def whisper_overheard(sender, receiver) do
    ~s[You overhear #{name(sender)} whispering to #{name(receiver)}.]
  end

  @doc """
  Format full text for a room
  """
  @spec room(Room.t(), [Item.t()], Map.t()) :: String.t()
  def room(room, items, map) do
    description = "#{room.description} #{room.features |> features() |> Enum.join(" ")}"

    """
    #{room_name(room)}
    #{underline(room.name)}
    #{description |> wrap()}\n
    #{map}

    #{who_is_here(room)}
    #{maybe_exits(room)}#{maybe_items(room, items)}#{shops(room)}
    """
    |> String.trim()
  end

  def room_name(room) do
    "{room}#{room.name}{/room}"
  end

  @doc """
  Display room features
  """
  def features([]), do: []

  def features([feature | list]) do
    [
      String.replace(feature.short_description, feature.key, "{white}#{feature.key}{/white}")
      | features(list)
    ]
  end

  @doc """
  Peak at a room from the room you're in

  Example:

    iex> Game.Format.peak_room(%{name: "Hallway"}, "north")
    "{room}Hallway{/room} is north."
  """
  @spec peak_room(Room.t(), String.t()) :: String.t()
  def peak_room(room, direction) do
    "#{room_name(room)} is #{direction}."
  end

  @doc """
  Create an 'underline'

  Example:

      iex> Game.Format.underline("Room Name")
      "-------------"

      iex> Game.Format.underline("{player}Player{/player}")
      "----------"
  """
  def underline(nil), do: ""

  def underline(string) do
    1..(String.length(Color.strip_color(string)) + 4)
    |> Enum.map(fn _ -> "-" end)
    |> Enum.join("")
  end

  @doc """
  Wraps lines of text
  """
  @spec wrap(String.t()) :: String.t()
  def wrap(string) do
    string
    |> String.replace("\n", " {newline} ")
    |> String.split()
    |> _wrap("", "")
  end

  @doc """
  Wraps a list of text
  """
  @spec wrap_lines([String.t()]) :: String.t()
  def wrap_lines(lines) do
    lines
    |> Enum.join(" ")
    |> wrap()
  end

  defp _wrap([], line, string), do: join(string, line, "\n")

  defp _wrap(["{newline}" | left], line, string) do
    case string do
      "" ->
        _wrap(left, "", line)

      _ ->
        _wrap(left, "", Enum.join([string, line], "\n"))
    end
  end

  defp _wrap([word | left], line, string) do
    test_line = "#{line} #{word}" |> Color.strip_color()

    case String.length(test_line) do
      len when len < 80 ->
        _wrap(left, join(line, word, " "), string)

      _ ->
        _wrap(left, word, join(string, line, "\n"))
    end
  end

  defp join(str1, str2, joiner) do
    Enum.join([str1, str2] |> Enum.reject(&(&1 == "")), joiner)
  end

  defp maybe_exits(room) do
    case room |> Room.exits() do
      [] ->
        ""

      _ ->
        "Exits: #{exits(room)}\n"
    end
  end

  defp exits(room) do
    room
    |> Room.exits()
    |> Enum.map(fn direction ->
      case Exit.exit_to(room, direction) do
        %{id: exit_id, has_door: true} ->
          "{exit}#{direction} (#{Door.get(exit_id)}){/exit}"

        _ ->
          "{exit}#{direction}{/exit}"
      end
    end)
    |> Enum.join(", ")
  end

  @doc """
  Format full text for who is in the room

  Example:

      iex> Game.Format.who_is_here(%{players: [%{name: "Mordred"}], npcs: [%{name: "Arthur", status_line: "[name] is here."}]})
      "{player}Mordred{/player} is here. {npc}Arthur{/npc} is here."
  """
  def who_is_here(room) do
    [players(room), npcs(room)]
    |> Enum.reject(fn line -> line == "" end)
    |> Enum.join(" ")
  end

  @doc """
  Format Player text for who is in the room

  Example:

      iex> Game.Format.players(%{players: [%{name: "Mordred"}, %{name: "Arthur"}]})
      "{player}Mordred{/player} is here. {player}Arthur{/player} is here."
  """
  @spec players(Room.t()) :: String.t()
  def players(%{players: players}) do
    players
    |> Enum.map(fn player -> "#{player_name(player)} is here." end)
    |> Enum.join(" ")
  end

  def players(_), do: ""

  @doc """
  Look at a Player
  """
  @spec player_full(User.t()) :: String.t()
  def player_full(user) do
    "[name] is here."
    |> template(%{name: player_name(user)})
  end

  @doc """
  Format NPC text for who is in the room

  Example:

      iex> Game.Format.npcs(%{npcs: [%{name: "Mordred", status_line: "[name] is in the room."}, %{name: "Arthur", status_line: "[name] is here."}]})
      "{npc}Mordred{/npc} is in the room. {npc}Arthur{/npc} is here."
  """
  @spec npcs(Room.t()) :: String.t()
  def npcs(%{npcs: npcs}) do
    npcs
    |> Enum.map(&npc_status/1)
    |> Enum.join(" ")
  end

  def npcs(_), do: ""

  @doc """
  The status of an NPC
  """
  def npc_status(npc) do
    template(npc.status_line, %{name: npc_name_for_status(npc)})
  end

  @doc """
  Look at an NPC
  """
  @spec npc_full(Npc.t()) :: String.t()
  def npc_full(npc) do
    npc.description
    |> template(%{name: npc_name(npc), status_line: npc_status(npc)})
  end

  def maybe_items(room, items) do
    case Enum.empty?(items) and room.currency == 0 do
      true ->
        ""

      false ->
        "Items: #{items(room, items)}\n"
    end
  end

  def items(room, items) when is_list(items) do
    items = items |> Enum.map(&item_name/1)

    (items ++ [currency(room)])
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(", ")
  end

  def items(_, _), do: ""

  @doc """
  Format currency
  """
  @spec currency(Save.t() | Room.t()) :: String.t()
  def currency(%{currency: currency}) when currency == 0, do: ""
  def currency(%{currency: currency}), do: "{cyan}#{currency} #{@currency}{/cyan}"
  def currency(currency) when is_integer(currency), do: "{cyan}#{currency} #{@currency}{/cyan}"

  @doc """
  Format Shop text for shops in the room

  Example:

      iex> Game.Format.shops(%{shops: [%{name: "Hole in the Wall"}]})
      "Shops: {shop}Hole in the Wall{/shop}\\n"

      iex> Game.Format.shops(%{shops: [%{name: "Hole in the Wall"}]}, label: false)
      "  - {shop}Hole in the Wall{/shop}"
  """
  @spec shops(Room.t()) :: String.t()
  def shops(room, opts \\ [])
  def shops(%{shops: []}, _opts), do: ""

  def shops(%{shops: shops}, label: false) do
    shops
    |> Enum.map(fn shop -> "  - #{shop_name(shop)}" end)
    |> Enum.join(", ")
  end

  def shops(%{shops: shops}, _) do
    shops =
      shops
      |> Enum.map(&shop_name/1)
      |> Enum.join(", ")

    "Shops: #{shops}\n"
  end

  def shops(_, _), do: ""

  def list_shop(shop, items), do: Game.Format.Shop.list(shop, items)

  @doc """
  Display an item

  Example:

      iex> string = Game.Format.item(%{name: "Short Sword", description: "A simple blade"})
      iex> Regex.match?(~r(Short Sword), string)
      true
  """
  @spec item(Item.t()) :: String.t()
  def item(item) do
    """
    #{item |> item_name()}
    #{item.name |> underline}
    #{item.description}
    #{item_stats(item)}
    """
    |> String.trim()
  end

  @doc """
  Format an items stats

      iex> Game.Format.item_stats(%{type: "armor", stats: %{slot: :chest}})
      "Slot: chest"

      iex> Game.Format.item_stats(%{type: "basic"})
      ""
  """
  @spec item_stats(Item.t()) :: String.t()
  def item_stats(item)

  def item_stats(%{type: "armor", stats: stats}) do
    "Slot: #{stats.slot}"
  end

  def item_stats(_), do: ""

  @doc """
  Format your inventory
  """
  @spec inventory(integer(), map(), map(), [Item.t()]) :: String.t()
  def inventory(currency, wearing, wielding, items) do
    items =
      items
      |> Enum.map(fn
        %{item: item, quantity: 1} -> "  - #{item_name(item)}"
        %{item: item, quantity: quantity} -> "  - {item}#{item.name} x#{quantity}{/item}"
      end)
      |> Enum.join("\n")

    """
    #{equipment(wearing, wielding)}
    You are holding:
    #{items}
    You have #{currency} #{@currency}.
    """
    |> String.trim()
  end

  @doc """
  Format your equipment

  Example:

      iex> wearing = %{chest: %{name: "Leather Armor"}}
      iex> wielding = %{right: %{name: "Short Sword"}, left: %{name: "Shield"}}
      iex> Game.Format.equipment(wearing, wielding)
      "You are wearing:\\n  - {item}Leather Armor{/item} on your chest\\nYou are wielding:\\n  - a {item}Shield{/item} in your left hand\\n  - a {item}Short Sword{/item} in your right hand"
  """
  @spec equipment(map(), map()) :: String.t()
  def equipment(wearing, wielding) do
    wearing =
      wearing
      |> Map.to_list()
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {part, item} -> "  - #{item_name(item)} on your #{part}" end)
      |> Enum.join("\n")

    wielding =
      wielding
      |> Map.to_list()
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {hand, item} -> "  - a #{item_name(item)} in your #{hand} hand" end)
      |> Enum.join("\n")

    ["You are wearing:", wearing, "You are wielding:", wielding]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  @doc """
  Format your info sheet
  """
  @spec info(User.t()) :: String.t()
  def info(user = %{save: save}) do
    %{stats: stats} = save

    rows = [
      ["Level", save.level],
      ["XP", save.experience_points],
      ["Spent XP", save.spent_experience_points],
      ["Health Points", "#{stats.health_points}/#{stats.max_health_points}"],
      ["Skill Points", "#{stats.skill_points}/#{stats.max_skill_points}"],
      ["Movement Points", "#{stats.move_points}/#{stats.max_move_points}"],
      ["Strength", stats.strength],
      ["Dexterity", stats.dexterity],
      ["Intelligence", stats.intelligence],
      ["Wisdom", stats.wisdom],
      ["Play Time", play_time(user.seconds_online)]
    ]

    Table.format("#{player_name(user)} - #{user.race.name} - #{user.class.name}", rows, [16, 15])
  end

  @doc """
  View information about another player
  """
  def short_info(user = %{save: save}) do
    rows = [
      ["Level", save.level],
      ["Flags", player_flags(user)]
    ]

    Table.format("#{player_name(user)} - #{user.race.name} - #{user.class.name}", rows, [12, 15])
  end

  @doc """
  Format player flags

      iex> Game.Format.player_flags(%{flags: ["admin"]})
      "{red}admin{/red}"

      iex> Game.Format.player_flags(%{flags: []})
      "none"
  """
  def player_flags(player, opts \\ [none: true])
  def player_flags(%{flags: []}, none: true), do: "none"
  def player_flags(%{flags: []}, none: false), do: ""

  def player_flags(%{flags: flags}, _opts) do
    flags
    |> Enum.map(&"{red}#{&1}{/red}")
    |> Enum.join(" ")
  end

  @doc """
  Format skills

      iex> skills = [%{level: 1, name: "Slash", points: 2, command: "slash", description: "Fight your foe"}]
      iex> Game.Format.skills(skills)
      "Level - Name - Points - Description\\n1 - Slash (slash) - 2sp - Fight your foe\\n"
  """
  @spec skills([Skill.t()]) :: String.t()
  def skills(skills)

  def skills(skills) do
    skills =
      skills
      |> Enum.map(&skill(&1))
      |> Enum.join("\n")

    """
    Level - Name - Points - Description
    #{skills}
    """
  end

  @doc """
  Format a skill

      iex> skill = %{level: 1, name: "Slash", points: 2, command: "slash", description: "Fight your foe"}
      iex> Game.Format.skill(skill)
      "1 - Slash (slash) - 2sp - Fight your foe"
  """
  @spec skill(Skill.t()) :: String.t()
  def skill(skill) do
    "#{skill.level} - #{skill.name} (#{skill.command}) - #{skill.points}sp - #{skill.description}"
  end

  @doc """
  Format a skill, from perspective of the user

      iex> Game.Format.skill_user(%{user_text: "Slash away"}, [], {:npc, %{name: "Bandit"}})
      "Slash away"

      iex> effects = [%{kind: "damage", type: :slashing, amount: 10}]
      iex> Game.Format.skill_user(%{user_text: "You slash away at [target]"}, effects, {:npc, %{name: "Bandit"}})
      "You slash away at {npc}Bandit{/npc}\\n10 slashing damage is dealt."
  """
  def skill_user(skill, effects, target)

  def skill_user(%{user_text: user_text}, skill_effects, target) do
    user_text =
      user_text
      |> template(%{target: target_name(target)})

    [user_text | effects(skill_effects)] |> Enum.join("\n")
  end

  @doc """
  Format a skill, from the perspective of a usee

      iex> Game.Format.skill_usee(%{usee_text: "Slash away"}, user: {:npc, %{name: "Bandit"}})
      "Slash away"

      iex> Game.Format.skill_usee(%{usee_text: "You were slashed at by [user]"}, user: {:npc, %{name: "Bandit"}})
      "You were slashed at by {npc}Bandit{/npc}"
  """
  def skill_usee(skill, opts \\ [])

  def skill_usee(%{usee_text: usee_text}, opts) do
    skill_usee(usee_text, opts)
  end

  def skill_usee(usee_text, opts) do
    usee_text
    |> template(%{user: target_name(Keyword.get(opts, :user))})
  end

  @doc """
  Message for users of items

      iex> Game.Format.user_item(%{name: "Potion", user_text: "You used [name] on [target]."}, target: {:npc, %{name: "Bandit"}}, user: {:user, %{name: "Player"}})
      "You used {item}Potion{/item} on {npc}Bandit{/npc}."
  """
  def user_item(item, opts \\ []) do
    item.user_text
    |> template(%{
      name: item_name(item),
      target: target_name(Keyword.get(opts, :target)),
      user: target_name(Keyword.get(opts, :user)),
    })
  end

  @doc """
  Message for usees of items

      iex> Game.Format.usee_item(%{name: "Potion", usee_text: "You used [name] on [target]."}, target: {:npc, %{name: "Bandit"}}, user: {:user, %{name: "Player"}})
      "You used {item}Potion{/item} on {npc}Bandit{/npc}."
  """
  def usee_item(item, opts \\ []) do
    item.usee_text
    |> template(%{
      name: item_name(item),
      target: target_name(Keyword.get(opts, :target)),
      user: target_name(Keyword.get(opts, :user)),
    })
  end

  @doc """
  Format a target name, blue for user, yellow for npc

    iex> Game.Format.target_name({:user, %{name: "Player"}})
    "{player}Player{/player}"

    iex> Game.Format.target_name({:npc, %{name: "Bandit"}})
    "{npc}Bandit{/npc}"
  """
  @spec target_name(Character.t()) :: String.t()
  def target_name({:npc, npc}), do: npc_name(npc)
  def target_name({:user, user}), do: player_name(user)

  def name(who), do: target_name(who)

  @doc """
  Colorize a user's name
  """
  @spec player_name(User.t()) :: String.t()
  def player_name(user), do: "{player}#{user.name}{/player}"

  @doc """
  Colorize an npc's name
  """
  @spec npc_name(NPC.t()) :: String.t()
  def npc_name(npc), do: "{npc}#{npc.name}{/npc}"

  def npc_name_for_status(npc) do
    case Map.get(npc, :is_quest_giver, false) do
      true -> "#{npc_name(npc)} ({yellow}!{/yellow})"
      false -> npc_name(npc)
    end
  end

  @doc """
  Format a quest name

    iex> Game.Format.quest_name(%{name: "Into the Dungeon"})
    "{quest}Into the Dungeon{/quest}"
  """
  def quest_name(quest) do
    "{quest}#{quest.name}{/quest}"
  end

  @doc """
  Format an items name, cyan

    iex> Game.Format.item_name(%{name: "Potion"})
    "{item}Potion{/item}"
  """
  @spec item_name(Item.t()) :: String.t()
  def item_name(item) do
    "{item}#{item.name}{/item}"
  end

  @doc """
  Format a skill name, white

    iex> Game.Format.skill_name(%{name: "Slash"})
    "{skill}Slash{/skill}"
  """
  @spec skill_name(Skill.t()) :: String.t()
  def skill_name(skill) do
    "{skill}#{skill.name}{/skill}"
  end

  @doc """
  Format a shop name, magenta

     iex> Game.Format.shop_name(%{name: "Shop"})
     "{shop}Shop{/shop}"
  """
  def shop_name(shop) do
    "{shop}#{shop.name}{/shop}"
  end

  @doc """
  Format effects for display.
  """
  def effects([]), do: []

  def effects([effect | remaining]) do
    case effect do
      %{kind: "damage"} ->
        ["#{effect.amount} #{effect.type} damage is dealt." | effects(remaining)]

      %{kind: "damage/over-time"} ->
        ["#{effect.amount} #{effect.type} damage is dealt." | effects(remaining)]

      %{kind: "recover", type: "health"} ->
        ["#{effect.amount} damage is healed." | effects(remaining)]

      %{kind: "recover", type: "skill"} ->
        ["#{effect.amount} skill points are recovered." | effects(remaining)]

      %{kind: "recover", type: "move"} ->
        ["#{effect.amount} move points are recovered." | effects(remaining)]

      _ ->
        effects(remaining)
    end
  end

  @doc """
  Format number of seconds online into a human readable string

      iex> Game.Format.play_time(125)
      "00h 02m 05s"

      iex> Game.Format.play_time(600)
      "00h 10m 00s"

      iex> Game.Format.play_time(3670)
      "01h 01m 10s"

      iex> Game.Format.play_time(36700)
      "10h 11m 40s"
  """
  @spec play_time(integer()) :: String.t()
  def play_time(seconds) do
    hours = seconds |> div(3600) |> to_string |> String.pad_leading(2, "0")
    minutes = seconds |> div(60) |> rem(60) |> to_string |> String.pad_leading(2, "0")
    seconds = seconds |> rem(60) |> to_string |> String.pad_leading(2, "0")

    "#{hours}h #{minutes}m #{seconds}s"
  end

  @doc """
  An item was dropped message

      iex> Game.Format.dropped({:npc, %{name: "NPC"}}, %{name: "Sword"})
      "{npc}NPC{/npc} dropped a {item}Sword{/item}."

      iex> Game.Format.dropped({:user, %{name: "Player"}}, %{name: "Sword"})
      "{player}Player{/player} dropped a {item}Sword{/item}."

      iex> Game.Format.dropped({:user, %{name: "Player"}}, {:currency, 100})
      "{player}Player{/player} dropped {item}100 gold{/item}."
  """
  @spec dropped(Character.t(), Item.t()) :: String.t()
  def dropped(who, {:currency, amount}) do
    "#{name(who)} dropped {item}#{amount} #{currency()}{/item}."
  end

  def dropped(who, item) do
    "#{name(who)} dropped a #{item_name(item)}."
  end

  @doc """
  Format mail for a user
  """
  @spec list_mail([Mail.t()]) :: String.t()
  def list_mail(mail) do
    rows =
      mail
      |> Enum.map(fn mail ->
        [to_string(mail.id), player_name(mail.sender), mail.title]
      end)

    Table.format("You have #{length(mail)} unread mail.", rows, [5, 20, 30])
  end

  @doc """
  Format a single piece of mail for a user

      iex> Game.Format.display_mail(%{id: 1,sender: %{name: "Player"}, title: "hello", body: "A\\nlong message"})
      "1 - {player}Player{/player} - hello\\n----------------------\\n\\nA\\nlong message"
  """
  @spec display_mail(Mail.t()) :: String.t()
  def display_mail(mail) do
    title = "#{mail.id} - #{player_name(mail.sender)} - #{mail.title}"
    "#{title}\n#{underline(title)}\n\n#{mail.body}"
  end

  @doc """
  Format the status of a user's quests
  """
  @spec quest_progress([QuestProgress.t()]) :: String.t()
  def quest_progress(quests) do
    rows =
      quests
      |> Enum.map(fn %{status: status, quest: quest} ->
        [to_string(quest.id), quest.name, quest.giver.name, status]
      end)

    Table.format("You have #{length(quests)} active quests.", rows, [5, 30, 20, 10])
  end

  @doc """
  Format the status of a user's quest
  """
  @spec quest_detail(QuestProgress.t(), Save.t()) :: String.t()
  def quest_detail(progress, save) do
    %{quest: quest} = progress
    steps = quest.quest_steps |> Enum.map(&quest_step(&1, progress, save))
    header = "#{quest.name} - #{progress.status}"

    """
    #{header}
    #{header |> underline()}

    #{quest.description |> wrap()}

    #{steps |> Enum.join("\n")}
    """
    |> String.trim()
  end

  defp quest_step(step, progress, save) do
    case step.type do
      "item/collect" ->
        current_step_progress = Quest.current_step_progress(step, progress, save)
        " - Collect #{item_name(step.item)} - #{current_step_progress}/#{step.count}"

      "item/give" ->
        current_step_progress = Quest.current_step_progress(step, progress, save)

        " - Give #{item_name(step.item)} to #{npc_name(step.npc)} - #{current_step_progress}/#{
          step.count
        }"

      "item/have" ->
        current_step_progress = Quest.current_step_progress(step, progress, save)
        " - Have #{item_name(step.item)} - #{current_step_progress}/#{step.count}"

      "npc/kill" ->
        current_step_progress = Quest.current_step_progress(step, progress, save)
        " - Kill #{npc_name(step.npc)} - #{current_step_progress}/#{step.count}"

      "room/explore" ->
        current_step_progress = Quest.current_step_progress(step, progress, save)
        " - Explore #{room_name(step.room)} - #{current_step_progress}"
    end
  end

  @doc """
  List out skills that a trainer will give
  """
  @spec trainable_skills(NPC.t(), [Skill.t()]) :: String.t()
  def trainable_skills(trainer, skills) do
    rows =
      skills
      |> Enum.map(fn {skill, cost} ->
        [to_string(skill.id), skill.name, skill.command, cost]
      end)

    rows = [["ID", "Name", "Command", "Cost"] | rows]

    Table.format("#{npc_name(trainer)} will train these skills:", rows, [5, 30, 20, 10])
  end

  @doc """
  Format a list of socials
  """
  def socials(socials) do
    rows =
      socials
      |> Enum.map(fn social ->
        [social.name, "{command}#{social.command}{/command}"]
      end)

    rows = [["Name", "Command"] | rows]

    Table.format("List of socials", rows, [20, 20])
  end

  @doc """
  View a single social
  """
  def social(social) do
    """
    #{social.name}
    #{underline(social.name)}
    Command: {command}#{social.command}{/command}

    With a target: {say}#{social.with_target}{/say}

    Without a target: {say}#{social.without_target}{/say}
    """
  end

  @doc """
  Format the social without_target text
  """
  def social_without_target(social, user) do
    "{say}#{social.without_target}{say}"
    |> template(%{user: player_name(user)})
  end

  @doc """
  Format the social with_target text
  """
  def social_with_target(social, user, target) do
    "{say}#{social.with_target}{say}"
    |> template(%{user: player_name(user), target: name(target)})
  end

  @doc """
  Format the user's config
  """
  @spec config(Save.t()) :: String.t()
  def config(save) do
    rows =
      save.config
      |> Enum.map(fn {key, value} ->
        [String.capitalize(to_string(key)), value]
      end)

    rows = [["Name", "On?"] | rows]

    max_size =
      rows
      |> Enum.map(fn row ->
        row
        |> Enum.at(1)
        |> to_string()
        |> Color.strip_color()
        |> String.length()
      end)
      |> Enum.max()

    Table.format("Config", rows, [10, max_size])
  end

  @doc """
  Format a list of bugs
  """
  @spec list_bugs([Bug.t()]) :: String.t()
  def list_bugs(bugs) do
    rows =
      bugs
      |> Enum.map(fn bug ->
        [to_string(bug.id), bug.title, to_string(bug.is_completed)]
      end)

    rows = [["ID", "Title", "Is Fixed?"] | rows]

    Table.format("Bugs", rows, [10, 30, 10])
  end

  @doc """
  Format a list of bugs
  """
  @spec show_bug(Bug.t()) :: String.t()
  def show_bug(bug) do
    """
    #{bug.title}
    #{underline(bug.title)}
    Fixed: #{bug.is_completed}

    #{bug.body}
    """
  end
end
