--[[
LuCI Controller for lpac eSIM Management

This controller provides HTTP API endpoints for managing eSIM profiles
on OpenWrt routers using the lpac command-line tool.

Architecture:
- Uses Modern LuCI (LuCI ng) with view() for frontend pages
- HTTP API endpoints via call() functions (NOT ubus RPC)
- JSON request/response format
- Delegates business logic to luci.model.lpac modules

Copyright (C) 2025
Licensed under GPL-3.0
--]]

module("luci.controller.lpac", package.seeall)

function index()
	-- Main menu entry
	entry({"admin", "network", "lpac"},
		alias("admin", "network", "lpac", "dashboard"),
		_("eSIM Management"), 60)

	-- View pages
	entry({"admin", "network", "lpac", "dashboard"},
		view("lpac/dashboard"),
		_("Dashboard"), 1)

	entry({"admin", "network", "lpac", "chip"},
		view("lpac/chip"),
		_("Chip Info"), 2)

	entry({"admin", "network", "lpac", "profiles"},
		view("lpac/profiles"),
		_("Profiles"), 3)

	entry({"admin", "network", "lpac", "download"},
		view("lpac/download"),
		_("Download"), 4)

	entry({"admin", "network", "lpac", "notifications"},
		view("lpac/notifications"),
		_("Notifications"), 5)

	entry({"admin", "network", "lpac", "settings"},
		view("lpac/settings"),
		_("Settings"), 6)

	entry({"admin", "network", "lpac", "about"},
		view("lpac/about"),
		_("About"), 7)

	-- API endpoints
	entry({"admin", "network", "lpac", "api", "system_info"},
		call("action_system_info")).leaf = true

	entry({"admin", "network", "lpac", "api", "dashboard_summary"},
		call("action_dashboard_summary")).leaf = true

	entry({"admin", "network", "lpac", "api", "chip_info"},
		call("action_chip_info")).leaf = true

	entry({"admin", "network", "lpac", "api", "get_eid"},
		call("action_get_eid")).leaf = true

	entry({"admin", "network", "lpac", "api", "list_profiles"},
		call("action_list_profiles")).leaf = true

	entry({"admin", "network", "lpac", "api", "get_profile"},
		call("action_get_profile")).leaf = true

	entry({"admin", "network", "lpac", "api", "enable_profile"},
		call("action_enable_profile")).leaf = true

	entry({"admin", "network", "lpac", "api", "disable_profile"},
		call("action_disable_profile")).leaf = true

	entry({"admin", "network", "lpac", "api", "delete_profile"},
		call("action_delete_profile")).leaf = true

	entry({"admin", "network", "lpac", "api", "set_nickname"},
		call("action_set_nickname")).leaf = true

	entry({"admin", "network", "lpac", "api", "download_profile"},
		call("action_download_profile")).leaf = true

	entry({"admin", "network", "lpac", "api", "list_notifications"},
		call("action_list_notifications")).leaf = true

	entry({"admin", "network", "lpac", "api", "process_notification"},
		call("action_process_notification")).leaf = true

	entry({"admin", "network", "lpac", "api", "remove_notification"},
		call("action_remove_notification")).leaf = true

	entry({"admin", "network", "lpac", "api", "process_all_notifications"},
		call("action_process_all_notifications")).leaf = true

	entry({"admin", "network", "lpac", "api", "remove_all_notifications"},
		call("action_remove_all_notifications")).leaf = true

	entry({"admin", "network", "lpac", "api", "discover_profiles"},
		call("action_discover_profiles")).leaf = true

	entry({"admin", "network", "lpac", "api", "set_default_smdp"},
		call("action_set_default_smdp")).leaf = true

	entry({"admin", "network", "lpac", "api", "factory_reset"},
		call("action_factory_reset")).leaf = true

	entry({"admin", "network", "lpac", "api", "list_apdu_drivers"},
		call("action_list_apdu_drivers")).leaf = true

	entry({"admin", "network", "lpac", "api", "list_http_drivers"},
		call("action_list_http_drivers")).leaf = true

	entry({"admin", "network", "lpac", "api", "check_lpac"},
		call("action_check_lpac")).leaf = true

	entry({"admin", "network", "lpac", "api", "get_config"},
		call("action_get_config")).leaf = true

	entry({"admin", "network", "lpac", "api", "update_config"},
		call("action_update_config")).leaf = true
end

-- Helper function to send JSON response
-- @param data table Data to serialize and send as JSON
local function send_json(data)
	local http = require "luci.http"
	http.prepare_content("application/json")
	http.write_json(data)
end

-- Helper function to get POST data
-- Parses JSON request body from HTTP POST request
-- @return table|nil Parsed JSON data or nil if no content
local function get_post_data()
	local http = require "luci.http"
	local json = require "luci.jsonc"

	local content = http.content()
	if not content or content == "" then
		return nil
	end

	return json.parse(content)
end

-- Get system information
-- Returns application version, lpac version, and system details
-- @return JSON response with system information
function action_system_info()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.get_system_info()
	send_json(result)
end

-- Get dashboard summary
-- Returns overview of eUICC status, profiles, and notifications
-- @return JSON response with dashboard data
function action_dashboard_summary()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.get_dashboard_summary()
	send_json(result)
end

-- Get chip information
-- Returns detailed eUICC chip information and capabilities
-- @return JSON response with formatted chip data
function action_chip_info()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.get_chip_info_formatted()
	send_json(result)
end

-- Get EID (eUICC Identifier)
-- @return JSON response with EID or error message
function action_get_eid()
	local lpac = require "luci.model.lpac.lpac_interface"
	local util = require "luci.model.lpac.lpac_util"

	local eid = lpac.get_eid()
	if eid then
		send_json(util.create_result(true, "Success", {eid = eid}))
	else
		send_json(util.create_result(false, "Failed to get EID", nil))
	end
end

-- List all eSIM profiles
-- Returns array of profiles with state, nickname, provider info
-- @return JSON response with profiles array
function action_list_profiles()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.list_profiles_enhanced()
	send_json(result)
end

-- Get single profile by ICCID
-- Query parameter: iccid (string) - Profile ICCID
-- @return JSON response with profile details or error
function action_get_profile()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local iccid = http.formvalue("iccid")
	if not iccid then
		send_json(util.create_result(false, "ICCID parameter is required", nil))
		return
	end

	local result = model.get_profile_by_iccid(iccid)
	send_json(result)
end

-- Enable profile
-- POST data: {iccid: string, refresh: boolean?}
-- Activates the specified profile on the eUICC
-- @return JSON response with success/failure status
function action_enable_profile()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data or not data.iccid then
		send_json(util.create_result(false, "ICCID is required", nil))
		return
	end

	local refresh = data.refresh ~= false  -- Default to true
	local result = model.enable_profile_safe(data.iccid, refresh)
	send_json(result)
end

-- Disable profile
-- POST data: {iccid: string, refresh: boolean?}
-- Deactivates the specified profile on the eUICC
-- @return JSON response with success/failure status
function action_disable_profile()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data or not data.iccid then
		send_json(util.create_result(false, "ICCID is required", nil))
		return
	end

	local refresh = data.refresh ~= false  -- Default to true
	local result = model.disable_profile_safe(data.iccid, refresh)
	send_json(result)
end

-- Delete profile
-- POST data: {iccid: string, confirmed: boolean}
-- Permanently removes the profile from the eUICC
-- @return JSON response with success/failure status
function action_delete_profile()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data or not data.iccid then
		send_json(util.create_result(false, "ICCID is required", nil))
		return
	end

	local confirmed = data.confirmed == true
	local result = model.delete_profile_safe(data.iccid, confirmed)
	send_json(result)
end

-- Set profile nickname
-- POST data: {iccid: string, nickname: string}
-- Updates the custom nickname for a profile
-- @return JSON response with success/failure status
function action_set_nickname()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data or not data.iccid or not data.nickname then
		send_json(util.create_result(false, "ICCID and nickname are required", nil))
		return
	end

	local result = model.set_nickname_safe(data.iccid, data.nickname)
	send_json(result)
end

-- Download profile
-- POST data: {activation_code?: string, smdp?: string, matching_id?: string, confirmation_code?: string, imei?: string}
-- Downloads and installs an eSIM profile using activation code or manual parameters
-- @return JSON response with success status and profile ICCID
function action_download_profile()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data then
		send_json(util.create_result(false, "Download options are required", nil))
		return
	end

	local opts = {
		activation_code = data.activation_code,
		smdp = data.smdp,
		matching_id = data.matching_id,
		confirmation_code = data.confirmation_code,
		imei = data.imei
	}

	-- Wrap in pcall to catch any Lua errors
	local success, result = pcall(function()
		return model.download_profile_safe(opts)
	end)

	if not success then
		-- Lua error occurred (exception)
		send_json(util.create_result(false, "Internal error: " .. tostring(result), nil))
		return
	end

	send_json(result)
end

-- List notifications
-- Returns array of pending eUICC notifications from SM-DP+ servers
-- @return JSON response with notifications array
function action_list_notifications()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.list_notifications_enhanced()
	send_json(result)
end

-- Process notification
-- POST data: {seq_number: number, remove?: boolean}
-- Processes a pending notification (install/enable/disable/delete)
-- @return JSON response with processing result
function action_process_notification()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data or not data.seq_number then
		send_json(util.create_result(false, "Sequence number is required", nil))
		return
	end

	local remove = data.remove == true
	local result = model.process_notification_safe(data.seq_number, remove)
	send_json(result)
end

-- Remove notification
-- POST data: {seq_number: number}
-- Removes a pending notification without processing it
-- @return JSON response with success/failure status
function action_remove_notification()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data or not data.seq_number then
		send_json(util.create_result(false, "Sequence number is required", nil))
		return
	end

	local result = model.remove_notification_safe(data.seq_number)
	send_json(result)
end

-- Process all notifications
-- Processes all pending notifications in batch
-- @return JSON response with results for each notification
function action_process_all_notifications()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.process_all_notifications_safe()
	send_json(result)
end

-- Remove all notifications
-- Removes all pending notifications without processing
-- @return JSON response with success/failure status
function action_remove_all_notifications()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.remove_all_notifications_safe()
	send_json(result)
end

-- Discover profiles from SM-DS
-- Queries the SM-DS server for available profiles
-- @return JSON response with discovered profiles array
function action_discover_profiles()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.discover_profiles_safe()
	send_json(result)
end

-- Set default SM-DP+ address
-- POST data: {address: string}
-- Configures the default SM-DP+ server for profile discovery
-- @return JSON response with success/failure status
function action_set_default_smdp()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data or not data.address then
		send_json(util.create_result(false, "SM-DP+ address is required", nil))
		return
	end

	local result = model.set_default_smdp_safe(data.address)
	send_json(result)
end

-- Factory reset
-- POST data: {confirmation: string}
-- Permanently deletes all profiles and resets eUICC to factory state
-- Requires confirmation="RESET" for safety
-- @return JSON response with success/failure status
function action_factory_reset()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data or not data.confirmation then
		send_json(util.create_result(false, "Confirmation is required", nil))
		return
	end

	local result = model.factory_reset_safe(data.confirmation)
	send_json(result)
end

-- List available APDU drivers
-- Returns array of available APDU interface drivers
-- @return JSON response with drivers array
function action_list_apdu_drivers()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.list_apdu_drivers_safe()
	send_json(result)
end

-- List available HTTP drivers
-- Returns array of available HTTP interface drivers
-- @return JSON response with drivers array
function action_list_http_drivers()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.list_http_drivers_safe()
	send_json(result)
end

-- Check if lpac is available
-- Verifies lpac binary installation and execution
-- @return JSON response with installed status and version
function action_check_lpac()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.check_lpac_available()
	send_json(result)
end

-- Get configuration
-- Returns current UCI configuration (APDU driver, default SM-DP+)
-- @return JSON response with configuration object
function action_get_config()
	local model = require "luci.model.lpac.lpac_model"
	local result = model.get_config()
	send_json(result)
end

-- Update configuration
-- POST data: {apdu_driver?: string, default_smdp?: string}
-- Updates UCI configuration with new settings
-- @return JSON response with success/failure status
function action_update_config()
	local http = require "luci.http"
	local model = require "luci.model.lpac.lpac_model"
	local util = require "luci.model.lpac.lpac_util"

	local data = get_post_data()
	if not data then
		send_json(util.create_result(false, "Configuration data is required", nil))
		return
	end

	local result = model.update_config(data)
	send_json(result)
end
