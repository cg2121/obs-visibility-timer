local repeat_hold, repeat_source

obs           = obslua
source_name   = ""
mode          = ""
total_ms      = 0
delay         = 0
hold          = 0
start_visible = true
settings_     = nil

function enable_source()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, true)
	end

	obs.obs_source_release(source);

	obs.timer_remove(enable_source)
end

function disable_source()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, false)
	end

	obs.obs_source_release(source)

	obs.timer_remove(disable_source)
end

function repeat_hold()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, not obs.obs_source_enabled(source))
	end

	obs.obs_source_release(source)

	obs.timer_remove(repeat_hold)
	obs.timer_add(repeat_source, total_ms)
end

function repeat_source()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, not obs.obs_source_enabled(source))
	end

	obs.obs_source_release(source)

	obs.timer_remove(repeat_source)
	obs.timer_add(repeat_hold, hold)
end

function start_timer()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		if (mode == "mode_hide") then
			obs.obs_source_set_enabled(source, true)
			obs.timer_add(disable_source, total_ms)
		elseif (mode == "mode_show") then
			obs.obs_source_set_enabled(source, false)
			obs.timer_add(enable_source, total_ms)
		elseif (mode == "mode_repeat") then
			obs.obs_source_set_enabled(source, start_visible)
			obs.timer_add(repeat_source, total_ms)
		end
	end

	obs.obs_source_release(source)

	obs.timer_remove(start_timer)
end

function activate(activating)
	obs.timer_remove(start_timer)
	obs.timer_remove(repeat_hold)
	obs.timer_remove(repeat_source)
	obs.timer_remove(disable_source)
	obs.timer_remove(enable_source)

	if activating then
		local source = obs.obs_get_source_by_name(source_name)

		if source == nil then
			return
		end

		obs.obs_source_release(source)

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
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
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

	local p = obs.obs_properties_add_list(props, "source", "Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local name = obs.obs_source_get_name(source)
			obs.obs_property_list_add_string(p, name, name)
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

function script_description()
	return "Sets a source to show/hide on a timer."
end

function script_update(settings)
	total_ms = obs.obs_data_get_int(settings, "duration_ms")
	delay = obs.obs_data_get_int(settings, "delay_ms")
	hold = obs.obs_data_get_int(settings, "hold_ms")
	source_name = obs.obs_data_get_string(settings, "source")
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
	obs.signal_handler_connect(sh, "source_show", source_activated)
	obs.signal_handler_connect(sh, "source_hide", source_deactivated)

	settings_ = settings
end

function script_unload()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, true)
	end

	obs.obs_source_release(source)
end
