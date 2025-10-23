-- lpac_interface.lua - lpac CLI interface layer
-- Copyright (C) 2025
-- Licensed under GPL-3.0

local json = require "luci.jsonc"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local nixio = require "nixio"

local M = {}

-- Get UCI configuration values
local function get_config(option, default)
	return uci:get("luci-lpac", "config", option) or default
end

-- Build environment variables for lpac execution
local function build_env()
	local env = {}

	-- APDU driver configuration
	local apdu_driver = get_config("apdu_driver", "pcsc")
	env.LPAC_APDU = apdu_driver

	-- APDU driver specific settings
	if apdu_driver == "qmi" or apdu_driver == "qmi_qrtr" then
		local qmi_slot = get_config("qmi_slot", "1")
		env.LPAC_APDU_SLOT = qmi_slot
	elseif apdu_driver == "pcsc" then
		local pcsc_reader = get_config("pcsc_reader", "")
		if pcsc_reader ~= "" then
			env.LPAC_APDU_PCSC_READER = pcsc_reader
		end
	end

	-- HTTP driver configuration
	local http_driver = get_config("http_driver", "curl")
	env.LPAC_HTTP = http_driver

	-- Custom ISD-R AID
	local custom_aid = get_config("custom_aid", "")
	if custom_aid ~= "" then
		env.LPAC_CUSTOM_ISD_R_AID = custom_aid
	end

	-- ES10x Maximum Segment Size
	local es10x_mss = get_config("es10x_mss", "")
	if es10x_mss ~= "" then
		env.LPAC_ES10X_MSS = es10x_mss
	end

	-- Debug options
	local debug_http = get_config("debug_http", "0")
	if debug_http == "1" then
		env.LPAC_DEBUG_HTTP = "1"
	end

	local debug_apdu = get_config("debug_apdu", "0")
	if debug_apdu == "1" then
		env.LPAC_DEBUG_APDU = "1"
	end

	return env
end

-- Convert environment table to string for command execution
local function env_to_string(env)
	local env_str = ""
	for k, v in pairs(env) do
		env_str = env_str .. string.format("%s='%s' ", k, v)
	end
	return env_str
end

-- Execute lpac command with proper error handling
function M.exec_lpac(args, custom_env)
	-- Build environment variables
	local env = build_env()

	-- Merge custom environment variables if provided
	if custom_env then
		for k, v in pairs(custom_env) do
			env[k] = v
		end
	end

	-- Build command
	local env_str = env_to_string(env)
	-- Escape each argument to handle special characters like $ in activation codes
	local escaped_args = {}
	for i, arg in ipairs(args) do
		-- Wrap each argument in single quotes and escape any existing single quotes
		escaped_args[i] = "'" .. arg:gsub("'", "'\\''") .. "'"
	end
	local args_str = table.concat(escaped_args, " ")
	local cmd = string.format("%s/usr/bin/lpac %s 2>&1", env_str, args_str)

	-- Log command for debugging
	local log_cmd = string.format("echo '[lpac-luci] Executing: lpac %s' >> /tmp/lpac-debug.log", args_str)
	os.execute(log_cmd)

	-- Execute command directly with io.popen (no timeout, waits for completion)
	local handle = io.popen(cmd)
	if not handle then
		os.execute("echo '[lpac-luci ERROR] Failed to execute lpac command' >> /tmp/lpac-debug.log")
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Failed to execute lpac command",
				raw_output = ""
			}
		}
	end

	-- Read all output
	local output = handle:read("*all")
	handle:close()

	-- Check if we got any output
	if not output or output == "" then
		os.execute("echo '[lpac-luci ERROR] No output from lpac' >> /tmp/lpac-debug.log")
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "No output from lpac command",
				raw_output = ""
			}
		}
	end

	-- Log output for debugging (first 200 chars)
	local log_output = string.format("echo '[lpac-luci] Output (truncated): %s' >> /tmp/lpac-debug.log", output:sub(1, 200):gsub("'", "'\\''"):gsub("\n", " "))
	os.execute(log_output)

	-- lpac returns multiple JSON lines, we need the last one with type="lpa"
	-- Parse all lines and find the final result
	local result = nil
	for line in output:gmatch("[^\r\n]+") do
		local parsed = json.parse(line)
		if parsed and parsed.type == "lpa" then
			-- This is the final result line
			result = parsed
		end
	end

	-- If no valid result found, try parsing the last line
	if not result then
		local last_line = output:match("([^\n]*)\n?$")
		if last_line and last_line ~= "" then
			result = json.parse(last_line)
		end
	end

	-- If JSON parsing fails, return error
	if not result then
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Failed to parse lpac output",
				raw_output = output
			}
		}
	end

	return result
end

-- Get lpac version
function M.get_version()
	local result = M.exec_lpac({"version"})
	if result and result.payload and result.payload.data then
		return result.payload.data
	end
	return "unknown"
end

-- Get chip information
function M.get_chip_info()
	return M.exec_lpac({"chip", "info"})
end

-- Get EID
function M.get_eid()
	local result = M.exec_lpac({"chip", "eid"})
	if result and result.payload and result.payload.code == 0 and result.payload.data then
		return result.payload.data
	end
	return nil
end

-- List profiles
function M.list_profiles()
	return M.exec_lpac({"profile", "list"})
end

-- Enable profile
-- @param iccid: ICCID of the profile to enable
-- @param refresh: boolean, whether to refresh the profile (default: true)
function M.enable_profile(iccid, refresh)
	local args = {"profile", "enable"}

	-- Validate ICCID
	if not iccid or type(iccid) ~= "string" or not iccid:match("^%d+$") then
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Invalid ICCID format"
			}
		}
	end

	-- Add ICCID
	table.insert(args, iccid)

	-- Add refresh flag after ICCID (1 or 0, default is 1 if not specified)
	-- lpac expects: lpac profile enable <ICCID> [1/0]
	if refresh ~= nil and refresh == false then
		table.insert(args, "0")
	end
	-- If refresh is true or nil, we omit it (lpac default is true)

	return M.exec_lpac(args)
end

-- Disable profile
-- @param iccid: ICCID of the profile to disable
-- @param refresh: boolean, whether to refresh the profile (default: true)
function M.disable_profile(iccid, refresh)
	local args = {"profile", "disable"}

	-- Validate ICCID
	if not iccid or type(iccid) ~= "string" or not iccid:match("^%d+$") then
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Invalid ICCID format"
			}
		}
	end

	-- Add ICCID
	table.insert(args, iccid)

	-- Add refresh flag after ICCID (1 or 0, default is 1 if not specified)
	-- lpac expects: lpac profile disable <ICCID> [1/0]
	if refresh ~= nil and refresh == false then
		table.insert(args, "0")
	end
	-- If refresh is true or nil, we omit it (lpac default is true)

	return M.exec_lpac(args)
end

-- Delete profile
-- @param iccid: ICCID of the profile to delete
function M.delete_profile(iccid)
	-- Validate ICCID
	if not iccid or type(iccid) ~= "string" or not iccid:match("^%d+$") then
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Invalid ICCID format"
			}
		}
	end

	return M.exec_lpac({"profile", "delete", iccid})
end

-- Set profile nickname
-- @param iccid: ICCID of the profile
-- @param nickname: New nickname for the profile
function M.set_nickname(iccid, nickname)
	-- Validate ICCID
	if not iccid or type(iccid) ~= "string" or not iccid:match("^%d+$") then
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Invalid ICCID format"
			}
		}
	end

	-- Validate and sanitize nickname
	if not nickname or type(nickname) ~= "string" then
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Invalid nickname"
			}
		}
	end

	-- Truncate nickname to 64 characters
	if #nickname > 64 then
		nickname = nickname:sub(1, 64)
	end

	return M.exec_lpac({"profile", "nickname", iccid, nickname})
end

-- Download profile
-- @param opts: table with download options
--   - activation_code: LPA activation code (LPA:1$...)
--   - smdp: SM-DP+ address (alternative to activation_code)
--   - matching_id: Matching ID (used with smdp)
--   - confirmation_code: Confirmation code (optional)
--   - imei: Custom IMEI (optional)
function M.download_profile(opts)
	if not opts or type(opts) ~= "table" then
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Invalid download options"
			}
		}
	end

	local args = {"profile", "download"}

	-- Use activation code if provided
	if opts.activation_code and opts.activation_code ~= "" then
		table.insert(args, "-a")
		table.insert(args, opts.activation_code)
	else
		-- Use manual entry (SM-DP+ address and matching ID)
		if opts.smdp and opts.smdp ~= "" then
			table.insert(args, "-s")
			table.insert(args, opts.smdp)
		end

		if opts.matching_id and opts.matching_id ~= "" then
			table.insert(args, "-m")
			table.insert(args, opts.matching_id)
		end
	end

	-- Add optional parameters
	if opts.confirmation_code and opts.confirmation_code ~= "" then
		table.insert(args, "-c")
		table.insert(args, opts.confirmation_code)
	end

	if opts.imei and opts.imei ~= "" then
		table.insert(args, "-i")
		table.insert(args, opts.imei)
	end

	return M.exec_lpac(args)
end

-- List notifications
function M.list_notifications()
	return M.exec_lpac({"notification", "list"})
end

-- Process notification
-- @param seq_number: Sequence number of the notification
-- @param remove: boolean, whether to remove after processing (default: false)
function M.process_notification(seq_number, remove)
	local args = {"notification", "process"}

	-- Add remove flag if requested
	if remove == true then
		table.insert(args, "-r")
	end

	-- Validate sequence number
	if not seq_number or type(seq_number) ~= "number" then
		-- Try to convert string to number
		seq_number = tonumber(seq_number)
		if not seq_number then
			return {
				type = "lpa",
				payload = {
					code = -1,
					message = "Invalid sequence number"
				}
			}
		end
	end

	table.insert(args, tostring(seq_number))

	return M.exec_lpac(args)
end

-- Remove notification
-- @param seq_number: Sequence number of the notification
function M.remove_notification(seq_number)
	-- Validate sequence number
	if not seq_number or type(seq_number) ~= "number" then
		seq_number = tonumber(seq_number)
		if not seq_number then
			return {
				type = "lpa",
				payload = {
					code = -1,
					message = "Invalid sequence number"
				}
			}
		end
	end

	return M.exec_lpac({"notification", "remove", tostring(seq_number)})
end

-- Process all notifications
function M.process_all_notifications()
	return M.exec_lpac({"notification", "process", "ALL"})
end

-- Remove all notifications
function M.remove_all_notifications()
	return M.exec_lpac({"notification", "remove", "ALL"})
end

-- Discover profiles from SM-DS
function M.discover_profiles()
	return M.exec_lpac({"profile", "discovery"})
end

-- Set default SM-DP+ address
-- @param address: SM-DP+ address
function M.set_default_smdp(address)
	if not address or type(address) ~= "string" or address == "" then
		return {
			type = "lpa",
			payload = {
				code = -1,
				message = "Invalid SM-DP+ address"
			}
		}
	end

	return M.exec_lpac({"chip", "defaultsmdp", address})
end

-- Factory reset (eUICC memory reset)
function M.factory_reset()
	return M.exec_lpac({"chip", "reset"})
end

-- List available APDU drivers
function M.list_apdu_drivers()
	return M.exec_lpac({"driver", "list"})
end

-- List available HTTP drivers
function M.list_http_drivers()
	return M.exec_lpac({"driver", "http", "list"})
end

return M
