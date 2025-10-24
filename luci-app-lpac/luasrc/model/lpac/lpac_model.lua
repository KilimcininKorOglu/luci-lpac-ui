-- lpac_model.lua - Business logic layer for lpac
-- Copyright (C) 2025
-- Licensed under GPL-3.0

local lpac = require "luci.model.lpac.lpac_interface"
local util = require "luci.model.lpac.lpac_util"
local uci = require "luci.model.uci".cursor()
local nixio = require "nixio"
local fs = require "nixio.fs"

local M = {}

-- Cooldown tracking (simple in-memory storage)
local last_download_time = nil

-- Get system information
function M.get_system_info()
	local sys = require "luci.sys"

	-- Read app version from VERSION file
	local version_file = "/usr/lib/lua/luci/model/lpac/VERSION"
	local app_version = "1.0.0"  -- fallback
	local f = io.open(version_file, "r")
	if f then
		app_version = f:read("*line") or "1.0.0"
		f:close()
	end

	local info = {
		openwrt_version = sys.exec("grep DISTRIB_RELEASE /etc/openwrt_release | cut -d= -f2 | tr -d \"'\""):gsub("\n", ""),
		luci_version = require("luci.version").luciversion or "unknown",
		lpac_version = lpac.get_version(),
		app_version = app_version
	}

	return info
end

-- Get chip information with formatted output
function M.get_chip_info_formatted()
	local result = lpac.get_chip_info()

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	local data = result.payload.data
	if not data then
		return util.create_result(false, util.ERROR_MESSAGES.CHIP_DATA_UNAVAILABLE, nil)
	end

	-- Format memory values
	if data.freeNvMemory then
		data.freeNvMemory_formatted = util.format_bytes(data.freeNvMemory * 1024)
	end

	if data.freeVolatileMemory then
		data.freeVolatileMemory_formatted = util.format_bytes(data.freeVolatileMemory * 1024)
	end

	return util.create_result(true, "Success", data)
end

-- List profiles with enhanced information
function M.list_profiles_enhanced()
	local result = lpac.list_profiles()

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	local profiles = result.payload.data or {}

	-- Enhance each profile with formatted data
	for _, profile in ipairs(profiles) do
		-- Mask ICCID for display
		profile.iccid_masked = util.mask_iccid(profile.iccid)

		-- Format state
		profile.profileState_formatted = util.format_profile_state(profile.profileState)

		-- Format class
		profile.profileClass_formatted = util.format_profile_class(profile.profileClass)

		-- Set display name (use nickname if available, else provider name)
		profile.displayName = profile.profileNickname or profile.serviceProviderName or "Unknown"
	end

	-- Sort profiles: enabled first, then by display name
	table.sort(profiles, function(a, b)
		if a.profileState == b.profileState then
			return a.displayName < b.displayName
		end
		return a.profileState == "enabled"
	end)

	return util.create_result(true, "Success", profiles)
end

-- Get single profile by ICCID
function M.get_profile_by_iccid(iccid)
	-- Validate ICCID
	local valid, err = util.validate_iccid(iccid)
	if not valid then
		return util.create_result(false, err, nil)
	end

	-- Get all profiles
	local result = M.list_profiles_enhanced()
	if not result.success then
		return result
	end

	-- Find matching profile
	for _, profile in ipairs(result.data) do
		if profile.iccid == iccid then
			return util.create_result(true, "Success", profile)
		end
	end

	return util.create_result(false, util.ERROR_MESSAGES.PROFILE_NOT_FOUND, nil)
end

-- Enable profile with validation
function M.enable_profile_safe(iccid, refresh)
	-- Validate ICCID
	local valid, err = util.validate_iccid(iccid)
	if not valid then
		return util.create_result(false, err, nil)
	end

	-- Prepare modem (stop wwan interface if needed)
	lpac.prepare_modem_for_lpac()

	-- Execute operation
	local result = lpac.enable_profile(iccid, refresh)

	-- Restore modem (SIM power cycle + restart wwan)
	lpac.restore_modem_after_lpac()

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Profile enabled successfully", result.payload.data)
end

-- Disable profile with validation
function M.disable_profile_safe(iccid, refresh)
	-- Validate ICCID
	local valid, err = util.validate_iccid(iccid)
	if not valid then
		return util.create_result(false, err, nil)
	end

	-- Prepare modem (stop wwan interface if needed)
	lpac.prepare_modem_for_lpac()

	-- Execute operation
	local result = lpac.disable_profile(iccid, refresh)

	-- Restore modem (SIM power cycle + restart wwan)
	lpac.restore_modem_after_lpac()

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Profile disabled successfully", result.payload.data)
end

-- Delete profile with validation and confirmation
function M.delete_profile_safe(iccid, confirmed)
	-- Check confirmation
	if not confirmed then
		return util.create_result(false, util.ERROR_MESSAGES.DELETION_REQUIRES_CONFIRMATION, nil)
	end

	-- Validate ICCID
	local valid, err = util.validate_iccid(iccid)
	if not valid then
		return util.create_result(false, err, nil)
	end

	-- Execute operation
	local result = lpac.delete_profile(iccid)

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Profile deleted successfully", result.payload.data)
end

-- Set profile nickname with validation
function M.set_nickname_safe(iccid, nickname)
	-- Validate ICCID
	local valid, err = util.validate_iccid(iccid)
	if not valid then
		return util.create_result(false, err, nil)
	end

	-- Sanitize nickname
	nickname = util.sanitize_nickname(nickname)
	if util.is_empty(nickname) then
		return util.create_result(false, util.ERROR_MESSAGES.NICKNAME_EMPTY, nil)
	end

	-- Execute operation
	local result = lpac.set_nickname(iccid, nickname)

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Nickname set successfully", result.payload.data)
end

-- Download profile with comprehensive validation and cooldown
function M.download_profile_safe(opts)
	-- DEBUG: Log function entry
	util.log("DEBUG", "[download_profile_safe] Function called")

	-- Check cooldown
	local cooldown_seconds = tonumber(uci:get("luci-lpac", "advanced", "download_cooldown")) or 60
	local can_proceed, remaining = util.check_cooldown(last_download_time, cooldown_seconds)

	if not can_proceed then
		util.log("DEBUG", "[download_profile_safe] Cooldown check failed")
		return util.create_result(false,
			string.format("Please wait %d seconds before downloading another profile", remaining),
			nil)
	end

	-- Validate options
	if not opts or type(opts) ~= "table" then
		util.log("DEBUG", "[download_profile_safe] Invalid opts type")
		return util.create_result(false, util.ERROR_MESSAGES.INVALID_DOWNLOAD_OPTIONS, nil)
	end

	util.log("DEBUG", "[download_profile_safe] opts.activation_code = " .. tostring(opts.activation_code))

	-- Validate activation code or manual entry
	if opts.activation_code and not util.is_empty(opts.activation_code) then
		util.log("DEBUG", "[download_profile_safe] Validating activation code: " .. opts.activation_code)
		local valid, err = util.validate_activation_code(opts.activation_code)
		if not valid then
			util.log("DEBUG", "[download_profile_safe] Validation failed: " .. tostring(err))
			return util.create_result(false, err, nil)
		end
		util.log("DEBUG", "[download_profile_safe] Validation passed")
	else
		-- Validate manual entry
		if util.is_empty(opts.smdp) then
			return util.create_result(false, util.ERROR_MESSAGES.SMDP_ADDRESS_REQUIRED, nil)
		end

		local valid, err = util.validate_smdp_address(opts.smdp)
		if not valid then
			return util.create_result(false, err, nil)
		end

		if util.is_empty(opts.matching_id) then
			return util.create_result(false, util.ERROR_MESSAGES.MATCHING_ID_REQUIRED, nil)
		end

		valid, err = util.validate_matching_id(opts.matching_id)
		if not valid then
			return util.create_result(false, err, nil)
		end
	end

	-- Validate optional confirmation code
	if opts.confirmation_code and not util.is_empty(opts.confirmation_code) then
		local valid, err = util.validate_confirmation_code(opts.confirmation_code)
		if not valid then
			return util.create_result(false, err, nil)
		end
	end

	-- Update cooldown timestamp
	last_download_time = os.time()

	-- Prepare modem (stop wwan interface if needed)
	lpac.prepare_modem_for_lpac()

	-- Execute download
	local result = lpac.download_profile(opts)

	-- Restore modem (SIM power cycle + restart wwan)
	lpac.restore_modem_after_lpac()

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	-- Auto-process notifications if enabled
	local auto_notification = uci:get("luci-lpac", "config", "auto_notification")
	if auto_notification == "1" then
		M.process_all_notifications_safe()
	end

	return util.create_result(true, "Profile downloaded successfully", result.payload.data)
end

-- List notifications with enhanced information
function M.list_notifications_enhanced()
	local result = lpac.list_notifications()

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	local notifications = result.payload.data or {}

	-- Enhance each notification
	for _, notif in ipairs(notifications) do
		-- Format operation
		notif.profileManagementOperation_formatted =
			util.format_notification_operation(notif.profileManagementOperation)

		-- Mask ICCID if present
		if notif.iccid then
			notif.iccid_masked = util.mask_iccid(notif.iccid)
		end
	end

	return util.create_result(true, "Success", notifications)
end

-- Process notification with validation
function M.process_notification_safe(seq_number, remove)
	-- Validate sequence number
	if not seq_number then
		return util.create_result(false, util.ERROR_MESSAGES.SEQUENCE_NUMBER_REQUIRED, nil)
	end

	seq_number = tonumber(seq_number)
	if not seq_number then
		return util.create_result(false, util.ERROR_MESSAGES.INVALID_SEQUENCE_NUMBER, nil)
	end

	-- Execute operation
	local result = lpac.process_notification(seq_number, remove)

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Notification processed successfully", result.payload.data)
end

-- Remove notification with validation
function M.remove_notification_safe(seq_number)
	-- Validate sequence number
	if not seq_number then
		return util.create_result(false, util.ERROR_MESSAGES.SEQUENCE_NUMBER_REQUIRED, nil)
	end

	seq_number = tonumber(seq_number)
	if not seq_number then
		return util.create_result(false, util.ERROR_MESSAGES.INVALID_SEQUENCE_NUMBER, nil)
	end

	-- Execute operation
	local result = lpac.remove_notification(seq_number)

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Notification removed successfully", result.payload.data)
end

-- Process all notifications
function M.process_all_notifications_safe()
	-- First, list all notifications
	local list_result = lpac.list_notifications()

	if not util.is_success(list_result) then
		return util.create_result(false, util.get_error_message(list_result), nil)
	end

	local notifications = list_result.payload.data or {}

	-- If no notifications, return success
	if #notifications == 0 then
		return util.create_result(true, "No notifications to process", nil)
	end

	-- Process each notification individually
	local processed = 0
	local failed = 0

	for _, notif in ipairs(notifications) do
		local seq_number = notif.seqNumber or notif.seq_number
		if seq_number then
			-- Process this notification (and remove it after processing)
			local result = lpac.process_notification(seq_number, true)
			if util.is_success(result) then
				processed = processed + 1
			else
				failed = failed + 1
			end
		end
	end

	if failed > 0 then
		return util.create_result(false,
			string.format("Processed %d, failed %d notifications", processed, failed),
			{processed = processed, failed = failed})
	end

	return util.create_result(true,
		string.format("All %d notifications processed successfully", processed),
		{processed = processed})
end

-- Remove all notifications
function M.remove_all_notifications_safe()
	-- First, list all notifications
	local list_result = lpac.list_notifications()

	if not util.is_success(list_result) then
		return util.create_result(false, util.get_error_message(list_result), nil)
	end

	local notifications = list_result.payload.data or {}

	-- If no notifications, return success
	if #notifications == 0 then
		return util.create_result(true, "No notifications to remove", nil)
	end

	-- Remove each notification individually
	local removed = 0
	local failed = 0

	for _, notif in ipairs(notifications) do
		local seq_number = notif.seqNumber or notif.seq_number
		if seq_number then
			local result = lpac.remove_notification(seq_number)
			if util.is_success(result) then
				removed = removed + 1
			else
				failed = failed + 1
			end
		end
	end

	if failed > 0 then
		return util.create_result(false,
			string.format("Removed %d, failed %d notifications", removed, failed),
			{removed = removed, failed = failed})
	end

	return util.create_result(true,
		string.format("All %d notifications removed successfully", removed),
		{removed = removed})
end

-- Discover profiles from SM-DS
function M.discover_profiles_safe()
	local result = lpac.discover_profiles()

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Profile discovery completed", result.payload.data)
end

-- Set default SM-DP+ address
function M.set_default_smdp_safe(address)
	-- Validate address
	if util.is_empty(address) then
		-- Clear default SM-DP+ (pass empty string)
		address = ""
	else
		local valid, err = util.validate_smdp_address(address)
		if not valid then
			return util.create_result(false, err, nil)
		end
	end

	local result = lpac.set_default_smdp(address)

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Default SM-DP+ address set successfully", result.payload.data)
end

-- Factory reset with confirmation
function M.factory_reset_safe(confirmed)
	-- Require explicit confirmation
	if not confirmed or confirmed ~= "CONFIRM_FACTORY_RESET" then
		return util.create_result(false, util.ERROR_MESSAGES.FACTORY_RESET_INVALID_CONFIRMATION, nil)
	end

	local result = lpac.factory_reset()

	if not util.is_success(result) then
		return util.create_result(false, util.get_error_message(result), nil)
	end

	return util.create_result(true, "Factory reset completed successfully", result.payload.data)
end

-- Get dashboard summary
function M.get_dashboard_summary()
	local summary = {
		chip_status = "disconnected",
		eid = nil,
		profiles_total = 0,
		profiles_enabled = 0,
		profiles_disabled = 0,
		notifications_pending = 0,
		free_memory = nil,
		firmware_version = nil,
		installed_apps = nil,
		free_nvm = nil,
		free_vm = nil
	}

	-- Get chip info
	local chip_result = lpac.get_chip_info()
	if util.is_success(chip_result) and chip_result.payload.data then
		summary.chip_status = "connected"
		summary.eid = chip_result.payload.data.eidValue
		summary.free_memory = chip_result.payload.data.freeNvMemory
		summary.firmware_version = chip_result.payload.data.euiccFirmwareVer

		-- Extended Card Resource data
		if chip_result.payload.data.extCardResource then
			local extResource = chip_result.payload.data.extCardResource
			summary.installed_apps = extResource.installedApplication
			summary.free_nvm = extResource.freeNonVolatileMemory
			summary.free_vm = extResource.freeVolatileMemory
		end
	end

	-- Get profiles
	local profiles_result = lpac.list_profiles()
	if util.is_success(profiles_result) and profiles_result.payload.data then
		local profiles = profiles_result.payload.data
		summary.profiles_total = #profiles

		for _, profile in ipairs(profiles) do
			if profile.profileState == "enabled" then
				summary.profiles_enabled = summary.profiles_enabled + 1
			else
				summary.profiles_disabled = summary.profiles_disabled + 1
			end
		end
	end

	-- Get notifications
	local notif_result = lpac.list_notifications()
	if util.is_success(notif_result) and notif_result.payload.data then
		summary.notifications_pending = #notif_result.payload.data
	end

	return util.create_result(true, "Success", summary)
end

-- List available APDU drivers
function M.list_apdu_drivers_safe()
	-- lpac 'driver list' command is not available in older versions
	-- Return hardcoded list of known APDU backends from lpac documentation
	local drivers = {
		"auto",      -- Auto-detect (default behavior)
		"pcsc",      -- PC/SC smart card interface
		"at",        -- AT command interface (ETSI)
		"at_csim",   -- AT command interface (CSIM variant)
		"qmi",       -- Qualcomm QMI protocol
		"qmi_qrtr",  -- QMI over QRTR transport
		"uqmi",      -- uqmi command-line interface
		"mbim",      -- Mobile Broadband Interface Model
		"stdio"      -- Standard I/O (for testing)
	}

	return util.create_result(true, "Success", {drivers = drivers})
end

-- List available HTTP drivers (hardcoded from lpac documentation)
function M.list_http_drivers_safe()
	-- lpac 'driver list' command is not available in older versions
	-- Return hardcoded list of known HTTP backends from lpac documentation
	local drivers = {
		"curl",      -- cURL HTTP client (default)
		"stdio"      -- Standard I/O (for testing)
	}

	return util.create_result(true, "Success", {drivers = drivers})
end

-- Check if lpac binary is available
function M.check_lpac_available()
	local available = fs.access("/usr/bin/lpac", "x")

	if not available then
		return util.create_result(false, util.ERROR_MESSAGES.LPAC_NOT_FOUND, {
			installed = false,
			path = "/usr/bin/lpac"
		})
	end

	return util.create_result(true, "lpac is available", {
		installed = true,
		path = "/usr/bin/lpac",
		version = lpac.get_version()
	})
end

-- Get configuration
function M.get_config()
	local config = {
		apdu_driver = uci:get("luci-lpac", "config", "apdu_driver") or "qmi",
		http_driver = uci:get("luci-lpac", "config", "http_driver") or "curl",
		custom_aid = uci:get("luci-lpac", "config", "custom_aid") or "",
		es10x_mss = uci:get("luci-lpac", "config", "es10x_mss") or "60",
		debug_http = uci:get("luci-lpac", "config", "debug_http") or "0",
		debug_apdu = uci:get("luci-lpac", "config", "debug_apdu") or "0",
		auto_notification = uci:get("luci-lpac", "config", "auto_notification") or "1",
		qmi_slot = uci:get("luci-lpac", "config", "qmi_slot") or "0",
		pcsc_reader = uci:get("luci-lpac", "config", "pcsc_reader") or "",
		log_level = uci:get("luci-lpac", "advanced", "log_level") or "info",
		timeout = uci:get("luci-lpac", "advanced", "timeout") or "120",
		download_cooldown = uci:get("luci-lpac", "advanced", "download_cooldown") or "60",
		auto_manage_wwan = uci:get("luci-lpac", "advanced", "auto_manage_wwan") or "1",
		wwan_interface = uci:get("luci-lpac", "advanced", "wwan_interface") or "wwan",
		auto_sim_power_cycle = uci:get("luci-lpac", "advanced", "auto_sim_power_cycle") or "1"
	}

	return util.create_result(true, "Success", config)
end

-- Update configuration
function M.update_config(new_config)
	if not new_config or type(new_config) ~= "table" then
		return util.create_result(false, util.ERROR_MESSAGES.INVALID_CONFIG_VALUE, nil)
	end

	-- Advanced section fields (stored in luci-lpac.advanced)
	local advanced_fields = {
		log_level = true,
		timeout = true,
		download_cooldown = true,
		auto_manage_wwan = true,
		wwan_interface = true,
		auto_sim_power_cycle = true
	}

	-- Update UCI configuration with proper section mapping
	for key, value in pairs(new_config) do
		local section = advanced_fields[key] and "advanced" or "config"
		local str_value = tostring(value)

		-- Set the UCI value
		local success = pcall(function()
			uci:set("luci-lpac", section, key, str_value)
		end)

		if not success then
			util.log("ERROR", "Failed to set UCI value: luci-lpac." .. section .. "." .. key .. " = " .. str_value)
			return util.create_result(false, "Failed to update configuration: " .. key, nil)
		end

		util.log("DEBUG", "Set UCI: luci-lpac." .. section .. "." .. key .. " = " .. str_value)
	end

	-- Commit changes with error handling
	local commit_success = pcall(function()
		uci:commit("luci-lpac")
	end)

	if not commit_success then
		util.log("ERROR", "Failed to commit UCI changes")
		return util.create_result(false, "Failed to commit configuration changes", nil)
	end

	util.log("INFO", "Configuration updated and committed successfully")

	-- Verify the changes were actually written (debugging aid)
	local verification = {}
	for key, _ in pairs(new_config) do
		local section = advanced_fields[key] and "advanced" or "config"
		local actual_value = uci:get("luci-lpac", section, key)
		verification[key] = actual_value
		util.log("DEBUG", "Verified UCI: luci-lpac." .. section .. "." .. key .. " = " .. tostring(actual_value))
	end

	return util.create_result(true, "Configuration updated successfully", verification)
end

return M
