local repeat_hold, repeat_source

obs           = obslua
source_name   = ""
mode          = ""
total_ms      = 0
delay         = 0
hold          = 0
activated     = false
start_visible = true

function enable_source()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, true)
	end

	obs.timer_remove(enable_source)
end

function disable_source()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, false)
	end

	obs.timer_remove(disable_source)
end

function repeat_hold()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, not obs.obs_source_enabled(source))
	end

	obs.timer_remove(repeat_hold)
	obs.timer_add(repeat_source, total_ms)
end

function repeat_source()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, not obs.obs_source_enabled(source))
	end

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

	obs.timer_remove(start_timer)
end

function activate(activating)
	if activated == activating then
		return
	end

	local source = obs.obs_get_source_by_name(source_name)

	if source == nil then
		return
	end

	activated = activating

	if activating then
		if delay ~= 0 then
			obs.timer_add(start_timer, delay)
		else
			start_timer()
		end
	else
		obs.timer_remove(start_timer)
		obs.timer_remove(repeat_hold)
		obs.timer_remove(repeat_source)
		obs.timer_remove(disable_source)
		obs.timer_remove(enable_source)
	end
end

-- Called when a source is activated/deactivated
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

----------------------------------------------------------

-- Can't get this to work

--function settings_modified(props, settings)
--	local prop = obs.obs_properties_get(props, "start_visible")
--	local mode_setting = obs.obs_settings_get(settings, "mode")

--	if (mode_setting == "mode_repeat") then
--		obs.obs_property_set_visible(prop, true)
--	else
--		obs.obs_property_set_visible(prop, false)
--	end

--	return true
--end

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = obs.obs_properties_create()

	local p = obs.obs_properties_add_list(props, "source", "Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			local name = obs.obs_source_get_name(source)
			local flags = obs.obs_source_get_flags(source)
			if (flags and obs.OBS_SOURCE_VIDEO) ~= 0 then
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	local mode = obs.obs_properties_add_list(props, "mode", "Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING);
	obs.obs_property_list_add_string(mode, "Hide source after specified time", "mode_hide");
	obs.obs_property_list_add_string(mode, "Show source after specified time", "mode_show");
	obs.obs_property_list_add_string(mode, "Repeat", "mode_repeat");

	obs.obs_properties_add_int(props, "delay", "Delay after activated (ms)", 0, 3600000, 1)
	obs.obs_properties_add_int(props, "duration", "Duration (seconds)", 1, 3600, 1)
	obs.obs_properties_add_int(props, "hold", "Repeat hold time (seconds)", 1, 3600, 1)

	obs.obs_properties_add_bool(props, "start_visible", "Start visible (repeat mode)");

	--obs.obs_property_set_modified_callback(p, settings_modified);

	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Sets a source to show/hide on a timer."
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	activate(false)

	total_ms = obs.obs_data_get_int(settings, "duration") * 1000
	delay = obs.obs_data_get_int(settings, "delay")
	hold = obs.obs_data_get_int(settings, "hold") * 1000
	source_name = obs.obs_data_get_string(settings, "source")
	mode = obs.obs_data_get_string(settings, "mode")
	start_visible = obs.obs_data_get_bool(settings, "start_visible")
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "duration", 5)
	obs.obs_data_set_default_int(settings, "delay", 0)
	obs.obs_data_set_default_int(settings, "hold", 5)
	obs.obs_data_set_default_bool(setting, "start_visible", true)
end

-- a function named script_load will be called on startup
function script_load(settings)
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
	-- unloaded.
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)
end

function script_unload()
	local source = obs.obs_get_source_by_name(source_name)

	if source ~= nil then
		obs.obs_source_set_enabled(source, true)
	end
end
