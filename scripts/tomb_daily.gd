class_name TombDaily
extends RefCounted
## The daily tomb: which tomb a day has, and what is kept of how it went.
##
## The day is the number of whole days since 1 January 1970 by the clock at
## Greenwich, so it turns over at the same moment for everyone, and the seed is
## made from nothing but that number: the same tomb everywhere, with no server.
## (The device's own clock is trusted: set it forward and tomorrow's tomb can
## be seen. Only a server handing out the seed would stop that.)
##
## What is kept is in `user://tombs.json` (on the web, the browser's storage):
## for each day, the best time and the first; and the run of days in a row.
## A finished run is a Dictionary (see `TombLevel`), and `submission` is that
## run as it would be sent to a leaderboard.

const FILE := "user://tombs.json"
## The day of tomb number 1: 1 October 2026.
const FIRST_DAY := 20727
## How hard each day of the week is, Sunday first.
const WEEK := [2, 0, 1, 1, 0, 1, 2]
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


static func today() -> int:
	return int(floor(Time.get_unix_time_from_system() / 86400.0))


## The number it is shown by: #1 on the first day.
static func number(day: int) -> int:
	return day - FIRST_DAY + 1


static func seed_for(day: int) -> int:
	return TombRandom.mix([0x7D0B, day])


static func difficulty_for(day: int) -> int:
	# (day 0 was a Thursday)
	return WEEK[posmod(day + 4, 7)]


static func date_text(day: int) -> String:
	var date := Time.get_date_dict_from_unix_time(day * 86400)
	return "%d %s %d" % [date["day"], MONTHS[int(date["month"]) - 1], date["year"]]


## A time as it is shown: 2:41.3
static func time_text(ms: int) -> String:
	var tenths := ms / 100
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


static func load_all() -> Dictionary:
	var kept := {"version": 1, "days": {}, "streak": {"last": 0, "length": 0, "best": 0}, "random_best": {}}
	if not FileAccess.file_exists(FILE):
		return kept
	var file := FileAccess.open(FILE, FileAccess.READ)
	if file == null:
		return kept
	var read: Variant = JSON.parse_string(file.get_as_text())
	if read is Dictionary:
		for key: String in kept:
			if read.has(key) and typeof(read[key]) == typeof(kept[key]):
				kept[key] = read[key]
	return kept


static func save_all(kept: Dictionary) -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(kept, "\t"))


## What is kept of a day, or an empty Dictionary: `best_ms`, `best_deaths`,
## `first_ms`, `first_deaths`, `runs`.
static func day_record(day: int) -> Dictionary:
	return load_all()["days"].get(str(day), {})


## The run of days in a row as it stands today (0 if yesterday was missed and today is not done).
static func streak() -> int:
	var kept: Dictionary = load_all()["streak"]
	return int(kept["length"]) if int(kept["last"]) >= today() - 1 else 0


## Keeps a finished run. Returns what there is to say about it: `best` (this
## was the best time for its day), `first` (the first finish of its day),
## `streak` (days in a row, with this one).
static func keep(run: Dictionary) -> Dictionary:
	var kept := load_all()
	var said := {"best": false, "first": false, "streak": 0}
	if run["mode"] != "daily":
		var key := "%d:%d" % [run["seed"], run["difficulty"]]
		var before: int = int(kept["random_best"].get(key, 0))
		said["best"] = before == 0 or int(run["time_ms"]) < before
		if said["best"]:
			kept["random_best"][key] = run["time_ms"]
		save_all(kept)
		return said
	var day := str(int(run["day"]))
	var record: Dictionary = kept["days"].get(day, {})
	said["first"] = record.is_empty()
	if record.is_empty():
		record = {"first_ms": run["time_ms"], "first_deaths": run["deaths"], "best_ms": run["time_ms"], "best_deaths": run["deaths"], "runs": 0}
		var streak_kept: Dictionary = kept["streak"]
		streak_kept["length"] = int(streak_kept["length"]) + 1 if int(streak_kept["last"]) == int(run["day"]) - 1 else 1
		streak_kept["last"] = int(run["day"])
		streak_kept["best"] = maxi(int(streak_kept["best"]), int(streak_kept["length"]))
	said["best"] = said["first"] or int(run["time_ms"]) < int(record["best_ms"])
	if said["best"]:
		record["best_ms"] = run["time_ms"]
		record["best_deaths"] = run["deaths"]
	record["runs"] = int(record["runs"]) + 1
	kept["days"][day] = record
	said["streak"] = int(kept["streak"]["length"])
	save_all(kept)
	return said


## The run in a line, to send to someone: `Outside daily tomb #123  2:41.3  1 death`
static func share_text(run: Dictionary) -> String:
	var deaths := int(run["deaths"])
	var died := "no deaths" if deaths == 0 else ("1 death" if deaths == 1 else "%d deaths" % deaths)
	if run["mode"] == "daily":
		return "Outside daily tomb #%d  %s  %s" % [number(int(run["day"])), time_text(int(run["time_ms"])), died]
	return "Outside tomb %d (%s)  %s  %s" % [run["seed"], TombGenerator.DIFFICULTY_NAMES[int(run["difficulty"])], time_text(int(run["time_ms"])), died]


## The run as a leaderboard would be sent it: everything needed to know which
## tomb it was (day, seed, difficulty, the generator's version, and the
## fingerprints of the plan and of the stone, which a server that made the
## tomb itself would check), what was done in it (the time in sixtieths of a
## second of play, the time to the treasure, deaths, and the time each room was
## first stood in), and `check`, a fingerprint of the rest. `check` only
## catches a damaged record: anyone can work it out. See README, "Tombs".
static func submission(run: Dictionary) -> Dictionary:
	var sent := {
		"v": 1, "mode": run["mode"], "day": run["day"], "seed": run["seed"], "difficulty": run["difficulty"],
		"generator": TombGenerator.VERSION, "plan": run["plan"], "stone": run["stone"],
		"ticks": run["ticks"], "time_ms": run["time_ms"], "goal_ms": run["goal_ms"], "deaths": run["deaths"], "splits": run["splits"],
	}
	sent["check"] = TombRandom.fingerprint(JSON.stringify(sent))
	return sent
