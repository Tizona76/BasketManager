
extends SceneTree
func _init():
	var paths = [
		"res://i18n/translations.fr.translation",
		"res://i18n/translations.en.translation",
		"res://i18n/translations.es.translation",
		"res://i18n/translations.it.translation",
		"res://i18n/translations.pt.translation",
	]
	print("=== I18N DUMP ===")
	print("locale=", TranslationServer.get_locale())

	for p in paths:
		var res = ResourceLoader.load(p)
		print("-- load ", p, " -> ", res)
		if res != null:
			TranslationServer.add_translation(res)
			if res is Translation:
				print("   msg(btn.back)=", (res as Translation).get_message("btn.back"))
				print("   msg(finance.title)=", (res as Translation).get_message("finance.title"))

	var keys = [
		"btn.back",
		"finance.title",
		"finance.income.title",
		"finance.income.tickets",
		"finance.income.shop",
		"finance.income.sponsors",
		"finance.expenses.title",
		"finance.expenses.salaries",
		"finance.expenses.staff",
		"finance.expenses.maintenance",
		"finance.balance.title",
	]
	print("=== tr() ===")
	for k in keys:
		print(k, " => ", tr(k))
	quit()
