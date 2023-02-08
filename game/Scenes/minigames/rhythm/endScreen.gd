extends Popup

func add_results(results:Dictionary):
	var res_str: String = "[center][color=#202124]Results[/color][/center]\n"
	var count: int = 0
	for p_name in results.keys():
		count += 1
		if count == 1:
			res_str += "[center][color=#f5a02a]1st: "
			res_str += p_name + "         " + str(results[p_name])
			res_str += "[/color][/center]\n"
		elif count == 2:
			res_str += "[center][color=#2af53b]2nd: "
			res_str += p_name + "         " + str(results[p_name])
			res_str += "[/color][/center]\n"
		elif count == 3:
			res_str += "[center][color=#eef52a]3rd: "
			res_str += p_name + "         " + str(results[p_name])
			res_str += "[/color][/center]\n"
		elif count == 4:
			res_str += "[center][color=#e72af5]4th: "
			res_str += p_name + "         " + str(results[p_name])
			res_str += "[/color][/center]\n"
	$results.bbcode_enabled = true
	$results.bbcode_text = res_str
