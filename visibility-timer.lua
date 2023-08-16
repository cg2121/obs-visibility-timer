local repeat_hold, repeat_source

obs           = obslua
source_name   = ""
group_name    = ""
mode          = ""
total_ms      = 0
delay         = 0
hold          = 0
start_visible = true
settings_     = nil

function get_item()
	
	if group_name ~= "" then
		local sceneSource = obs.obs_frontend_get_current_scene()
		local scene = obs.obs_scene_from_source(sceneSource)		
		local gSceneItem = obs.obs_scene_find_source(scene, group_name)		
		if gSceneItem ~= nil then
			local groupItems = obs.obs_sceneitem_group_enum_items(gSceneItem)
			if groupItems ~= nil then
				for _, sceneitem in ipairs(groupItems) do
					local sceneGroupItemSource = obs.obs_sceneitem_get_source(sceneitem)
					if sceneGroupItemSource ~= nil then
						local isn = obs.obs_source_get_name(sceneGroupItemSource)
						if source_name == isn then
							obs.obs_sceneitem_release(sceneitem)
							return sceneitem
						end
					end					
				end
			end			
		end
	else
		local source = obs.obs_frontend_get_current_scene()
		local scene = obs.obs_scene_from_source(source)
		local item = obs.obs_scene_find_source(scene, source_name)
		obs.obs_source_release(source)
		return item
	end

end

function enable_source()
	obs.obs_sceneitem_set_visible(get_item(), true)

	obs.timer_remove(enable_source)
end

function disable_source()
	obs.obs_sceneitem_set_visible(get_item(), false)

	obs.timer_remove(disable_source)
end

function repeat_hold()
	local item = get_item()
	local visible = obs.obs_sceneitem_visible(item)

	obs.obs_sceneitem_set_visible(item, not visible)

	obs.timer_remove(repeat_hold)
	obs.timer_add(repeat_source, total_ms + obs.obs_sceneitem_get_transition_duration(item, not visible))
end

function repeat_source()
	local item = get_item()
	local visible = obs.obs_sceneitem_visible(item)

	obs.obs_sceneitem_set_visible(item, not visible)

	obs.timer_remove(repeat_source)
	obs.timer_add(repeat_hold, hold + obs.obs_sceneitem_get_transition_duration(item, not visible))
end

function start_timer()
	local item = get_item()

	if item == nil then
		return
	end

	if (mode == "mode_hide") then
		obs.obs_sceneitem_set_visible(item, true)
		obs.timer_add(disable_source, total_ms + obs.obs_sceneitem_get_transition_duration(item, false))
	elseif (mode == "mode_show") then
		obs.obs_sceneitem_set_visible(item, false)
		obs.timer_add(enable_source, total_ms + obs.obs_sceneitem_get_transition_duration(item, true))
	elseif (mode == "mode_repeat") then
		obs.obs_sceneitem_set_visible(item, start_visible)
		obs.timer_add(repeat_source, total_ms + obs.obs_sceneitem_get_transition_duration(item, not start_visible))
	end

	obs.timer_remove(start_timer)
end

function activate(activating)	
	obs.timer_remove(start_timer)
	obs.timer_remove(repeat_hold)
	obs.timer_remove(repeat_source)
	obs.timer_remove(disable_source)
	obs.timer_remove(enable_source)
	obs.timer_remove(toggle_source)

	if activating then
		if delay ~= 0 then			
			obs.timer_add(start_timer, delay)
		else			
			start_timer()
		end
	end
end

function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	if (mode == "mode_hide") then
		activate_signal(cd, true)
	end
end

function source_deactivated(cd)
	if (mode == "mode_show") then
		activate_signal(cd, true)
	end
end

function settings_modified(props, prop, settings)
	local mode_setting = obs.obs_data_get_string(settings, "mode")
	local start = obs.obs_properties_get(props, "start_visible")
	local hold = obs.obs_properties_get(props, "hold_ms")

	local enabled

	if (mode_setting == "mode_repeat") then
		enabled = true
	else
		enabled = false
	end

	obs.obs_property_set_visible(start, enabled)
	obs.obs_property_set_visible(hold, enabled)

	return true
end

function script_properties()
	local props = obs.obs_properties_create()

	local mode = obs.obs_properties_add_list(props, "mode", "Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(mode, "Hide source after specified time", "mode_hide")
	obs.obs_property_list_add_string(mode, "Show source after specified time", "mode_show")
	obs.obs_property_list_add_string(mode, "Repeat", "mode_repeat")

	local pg = obs.obs_properties_add_list(props, "sourcegroup", "Group", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local p = obs.obs_properties_add_list(props, "source", "Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local name = obs.obs_source_get_name(source)
			obs.obs_property_list_add_string(p, name, name)
			obs.obs_property_list_add_string(pg, name, name)
		end
	end
	obs.source_list_release(sources)

	obs.obs_properties_add_int(props, "delay_ms", "Delay after activated (ms)", 0, 3600000, 1)
	obs.obs_properties_add_int(props, "duration_ms", "Duration (ms)", 1, 3600000, 1)
	obs.obs_properties_add_int(props, "hold_ms", "Hold time (ms)", 1, 3600000, 1)

	obs.obs_properties_add_bool(props, "start_visible", "Start visible")

	obs.obs_property_set_modified_callback(mode, settings_modified)

	settings_modified(props, nil, settings_)

	return props
end

function on_event(event)
	if event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then		
		activate(true)
	end
end

function script_description()
	return "Sets a source to show/hide on a timer."
end

function script_update(settings)
	total_ms = obs.obs_data_get_int(settings, "duration_ms")
	delay = obs.obs_data_get_int(settings, "delay_ms")
	hold = obs.obs_data_get_int(settings, "hold_ms")
	source_name = obs.obs_data_get_string(settings, "source")
	group_name = obs.obs_data_get_string(settings, "sourcegroup")
	mode = obs.obs_data_get_string(settings, "mode")
	start_visible = obs.obs_data_get_bool(settings, "start_visible")

	activate(true)
end

function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "duration_ms", 1000)
	obs.obs_data_set_default_int(settings, "delay_ms", 0)
	obs.obs_data_set_default_int(settings, "hold_ms", 1000)
	obs.obs_data_set_default_bool(setting, "start_visible", true)
end

function script_load(settings)	
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactive", source_deactivated)

	obs.obs_frontend_add_event_callback(on_event)

	settings_ = settings
end
