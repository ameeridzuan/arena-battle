extends CanvasLayer
## Lobby presentation only. The session authority validates all choices and start requests.
const CHARACTERS := ["Arclight", "Ashen Warden"]
var session: Node
var panel: Control
var roster_labels: Array[Label] = []
var character: OptionButton
var team: OptionButton
var ready_button: Button
var start: Button
var status: Label
var heading: Label
var skill_description: Label
var _was_waiting := true

func _ready() -> void:
	session = get_parent()
	layer = 5
	panel = ColorRect.new()
	panel.color = Color("101c30")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 64)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 80)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	heading = Label.new()
	heading.text = "WAITING LOBBY  |  0 / 4 PLAYERS"
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	var help := Label.new()
	help.text = "Choose your team and character, then mark Ready. The host starts the match.
Play 1v1, 2v1 or 2v2. Empty slots are allowed; no bots are added."
	column.add_child(help)
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 32)
	column.add_child(teams)
	for index in 2:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		teams.add_child(box)
		var title := Label.new()
		title.text = "TEAM " + ("A  /  BLUE" if index == 0 else "B  /  ORANGE")
		title.modulate = session.TEAM_COLORS[index]
		title.add_theme_font_size_override("font_size", 24)
		box.add_child(title)
		var label := Label.new()
		label.custom_minimum_size.y = 116
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
		roster_labels.append(label)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	column.add_child(choices)
	team = OptionButton.new()
	team.add_item("Team A / Blue", 0)
	team.add_item("Team B / Orange", 1)
	team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(team)
	character = OptionButton.new()
	for name in CHARACTERS:
		character.add_item(name)
	character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(character)
	team.item_selected.connect(func(_index): _select(false))
	character.item_selected.connect(func(_index): _select(false))
	skill_description = Label.new()
	skill_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(skill_description)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	ready_button = Button.new()
	ready_button.text = "Ready"
	ready_button.custom_minimum_size = Vector2(240, 48)
	ready_button.pressed.connect(_toggle_ready)
	actions.add_child(ready_button)
	start = Button.new()
	start.text = "Start match (host)"
	start.custom_minimum_size = Vector2(280, 48)
	start.pressed.connect(session.start_lobby_match)
	actions.add_child(start)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	session.lobby_updated.connect(_refresh)
	_refresh()

func _local_record() -> Dictionary:
	for record in session.lobby_roster:
		if record.id == session._local_peer_id:
			return record
	return {}

func _select(is_ready: bool) -> void:
	session.select_lobby(team.selected, character.selected, is_ready)

func _toggle_ready() -> void:
	_select(not bool(_local_record().get("ready", false)))

func _refresh() -> void:
	if not is_instance_valid(panel):
		return
	var local := _local_record()
	heading.text = "WAITING LOBBY  |  %d / 4 PLAYERS" % session.lobby_roster.size()
	var counts := [0, 0]
	for index in 2:
		var lines: Array[String] = []
		for record in session.lobby_roster:
			if record.team != index:
				continue
			counts[index] += 1
			var who := "You" if record.id == session._local_peer_id else "Player %s" % str(record.id).right(4)
			if record.id == session.lobby_host_id:
				who += " (Host)"
			var state := "Ready" if record.ready else ("Choosing" if record.loaded else "Loading...")
			lines.append("%s  |  %s  |  %s" % [who, CHARACTERS[record.character], state])
		while lines.size() < 2:
			lines.append("Open slot - waiting for player")
		roster_labels[index].text = "\n\n".join(lines)
	if not local.is_empty():
		team.select(local.team)
		character.select(local.character)
	skill_description.text = "[G] Pulse Grenade: throw a grenade that stuns enemies for 4 seconds. Cooldown: 18 seconds." if character.selected == 0 else "[G] Flame Scythe: wield a burning scythe for 20 seconds. Cooldown: 40 seconds."
	team.disabled = local.is_empty() or not session.connected
	character.disabled = team.disabled
	ready_button.disabled = local.is_empty() or not session.connected or not local.get("loaded", false)
	ready_button.text = "Not ready" if local.get("ready", false) else "Ready"
	start.visible = session._local_peer_id == session.lobby_host_id and session.lobby_host_id > 0
	start.disabled = not session.lobby_start_reason.is_empty() or not session.connected
	start.text = "Start %dv%d" % [counts[0], counts[1]]
	status.text = session.lobby_notice if not session.lobby_notice.is_empty() else session.lobby_start_reason
	if status.text.is_empty():
		status.text = "Everyone is ready. Host can start the match."

func _process(_delta: float) -> void:
	var waiting: bool = session.manager == null or session.manager.phase == 0
	panel.visible = waiting
	if waiting:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if not session.connected:
			status.text = session.status_text
	if waiting != _was_waiting:
		_was_waiting = waiting
		_refresh()
