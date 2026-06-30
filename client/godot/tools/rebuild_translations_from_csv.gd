
extends SceneTree

func _quit(msg: String) -> void:
	print(msg)
	quit()

func _safe_strip(s: String) -> String:
	return s.strip_edges(true, true)

func _norm_lang(s: String) -> String:
	var t := _safe_strip(s).to_lower()
	if t.length() >= 2:
		return t.substr(0, 2)
	return t

func _init():
	var csv_path := "res://i18n/translations.csv"
	if not FileAccess.file_exists(csv_path):
		_quit("[I18N][ERR] CSV introuvable: " + csv_path)

	var f := FileAccess.open(csv_path, FileAccess.READ)
	if f == null:
		_quit("[I18N][ERR] Impossible d'ouvrir: " + csv_path)

	if f.eof_reached():
		_quit("[I18N][ERR] CSV vide: " + csv_path)

	var header := f.get_csv_line()
	if header.size() < 2:
		_quit("[I18N][ERR] Header CSV invalide: " + str(header))

	var langs: Array[String] = []
	var col_lang: Array[String] = []
	for i in range(1, header.size()):
		var lg := _norm_lang(str(header[i]))
		if lg == "":
			continue
		langs.append(lg)
		col_lang.append(lg)

	if langs.size() == 0:
		_quit("[I18N][ERR] Aucun code langue trouvé dans le header: " + str(header))

	var tr_map := {}
	for lg in langs:
		var t := Translation.new()
		t.locale = lg
		tr_map[lg] = t

	var count_rows := 0
	var count_msgs := 0

	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 0:
			continue

		var key := _safe_strip(str(row[0]))
		if key == "" or key.begins_with("#"):
			continue

		count_rows += 1

		for i in range(1, min(row.size(), header.size())):
			var lg := col_lang[i - 1]
			var msg := _safe_strip(str(row[i]))
			if msg == "":
				continue
			var tr_res: Translation = tr_map[lg]
			tr_res.add_message(key, msg)
			count_msgs += 1

	f.close()

	var out = {
		"fr": "res://i18n/translations.fr.translation",
		"en": "res://i18n/translations.en.translation",
		"es": "res://i18n/translations.es.translation",
		"it": "res://i18n/translations.it.translation",
		"pt": "res://i18n/translations.pt.translation",
	}

	for lg in out.keys():
		if tr_map.has(lg):
			var path: String = str(out[lg])
			var err := ResourceSaver.save(tr_map[lg], path)
			print("[I18N] save ", lg, " -> ", path, " err=", err)
		else:
			print("[I18N][WARN] langue absente dans CSV: ", lg)

	print("[I18N] rows=", count_rows, " messages=", count_msgs)
	quit()
