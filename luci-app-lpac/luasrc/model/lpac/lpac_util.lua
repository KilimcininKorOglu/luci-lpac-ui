-- lpac_util.lua - Utility functions for lpac
-- Copyright (C) 2025
-- Licensed under GPL-3.0

local M = {}

-- Error message constants
-- Centralized error messages for consistent user feedback
M.ERROR_MESSAGES = {
	-- Generic errors
	UNKNOWN_ERROR = "An unknown error occurred",
	OPERATION_FAILED = "Operation failed",

	-- lpac binary errors
	LPAC_NOT_FOUND = "lpac binary not found or not executable",
	LPAC_EXECUTION_FAILED = "Failed to execute lpac command",

	-- Profile errors
	PROFILE_NOT_FOUND = "Profile not found",
	PROFILE_ALREADY_ENABLED = "Profile is already enabled",
	PROFILE_ALREADY_DISABLED = "Profile is already disabled",
	INVALID_ICCID = "Invalid ICCID format",

	-- Chip errors
	CHIP_NOT_CONNECTED = "eUICC chip is not connected",
	CHIP_DATA_UNAVAILABLE = "No chip data returned",
	CHIP_INFO_FAILED = "Failed to retrieve chip information",

	-- Download errors
	DOWNLOAD_FAILED = "Profile download failed",
	INVALID_ACTIVATION_CODE = "Invalid activation code format",
	SMDP_ADDRESS_REQUIRED = "SM-DP+ address is required",
	INVALID_DOWNLOAD_OPTIONS = "Invalid download options",

	-- Notification errors
	NOTIFICATION_NOT_FOUND = "Notification not found",
	NOTIFICATION_PROCESS_FAILED = "Failed to process notification",
	SEQUENCE_NUMBER_REQUIRED = "Sequence number is required",
	INVALID_SEQUENCE_NUMBER = "Invalid sequence number",
	MATCHING_ID_REQUIRED = "Matching ID is required",

	-- Configuration errors
	CONFIG_LOAD_FAILED = "Failed to load configuration",
	CONFIG_SAVE_FAILED = "Failed to save configuration",
	INVALID_CONFIG_VALUE = "Invalid configuration value",

	-- Validation errors
	CONFIRMATION_REQUIRED = "Confirmation is required",
	DELETION_REQUIRES_CONFIRMATION = "Deletion requires confirmation",
	NICKNAME_EMPTY = "Nickname cannot be empty",
	FACTORY_RESET_INVALID_CONFIRMATION = "Invalid confirmation code. Type 'RESET' to confirm",

	-- Permission errors
	PERMISSION_DENIED = "Permission denied",
	UNAUTHORIZED_OPERATION = "Unauthorized operation"
}

-- Mask ICCID for privacy (show first 4 and last 3 digits)
-- Example: 8901170000123456890 -> 8901***890
function M.mask_iccid(iccid)
	if not iccid or type(iccid) ~= "string" then
		return "***"
	end

	local len = #iccid
	if len < 10 then
		return "***"
	end

	return iccid:sub(1, 4) .. "***" .. iccid:sub(len - 2, len)
end

-- Validate ICCID format
-- ICCID should be 19-20 digits
function M.validate_iccid(iccid)
	if not iccid or type(iccid) ~= "string" then
		return false, "ICCID must be a string"
	end

	if not iccid:match("^%d+$") then
		return false, "ICCID must contain only digits"
	end

	local len = #iccid
	if len < 19 or len > 20 then
		return false, "ICCID must be 19-20 digits long"
	end

	return true
end

-- Validate EID format
-- EID should be 32 digits
function M.validate_eid(eid)
	if not eid or type(eid) ~= "string" then
		return false, "EID must be a string"
	end

	if not eid:match("^%d+$") then
		return false, "EID must contain only digits"
	end

	if #eid ~= 32 then
		return false, "EID must be 32 digits long"
	end

	return true
end

-- Validate activation code format
-- Format: LPA:1$SMDP_ADDRESS$MATCHING_ID[$CONFIRMATION_CODE]
function M.validate_activation_code(code)
	if not code or type(code) ~= "string" then
		return false, "Activation code must be a string"
	end

	-- Check if it starts with LPA:1$
	if not code:match("^LPA:1%$") then
		return false, "Activation code must start with 'LPA:1$'"
	end

	-- Check if it has at least SMDP and Matching ID
	-- Format: LPA:1$SMDP_ADDRESS$MATCHING_ID or LPA:1$SMDP_ADDRESS$MATCHING_ID$CONFIRMATION_CODE
	-- After splitting by $, we get parts: ["LPA:1", "SMDP_ADDRESS", "MATCHING_ID", ...]
	-- So minimum is 3 parts (LPA:1, address, matching_id)
	local parts = {}
	for part in code:gmatch("[^$]+") do
		table.insert(parts, part)
	end

	-- We need at least 3 parts: LPA:1, SMDP address, and Matching ID
	if #parts < 3 then
		return false, "Activation code must contain SM-DP+ address and matching ID (found " .. #parts .. " parts)"
	end

	return true
end

-- Sanitize nickname (remove special characters, limit length)
function M.sanitize_nickname(nickname)
	if not nickname or type(nickname) ~= "string" then
		return ""
	end

	-- Remove leading/trailing whitespace
	nickname = nickname:match("^%s*(.-)%s*$")

	-- Limit to 64 characters
	if #nickname > 64 then
		nickname = nickname:sub(1, 64)
	end

	return nickname
end

-- Format profile state for display
function M.format_profile_state(state)
	if state == "enabled" then
		return "Enabled"
	elseif state == "disabled" then
		return "Disabled"
	else
		return "Unknown"
	end
end

-- Format profile class for display
function M.format_profile_class(class)
	if class == "operational" then
		return "Operational"
	elseif class == "provisioning" then
		return "Provisioning"
	elseif class == "test" then
		return "Test"
	else
		return class or "Unknown"
	end
end

-- Format notification operation for display
function M.format_notification_operation(operation)
	local operations = {
		install = "Install",
		enable = "Enable",
		disable = "Disable",
		delete = "Delete"
	}
	return operations[operation] or operation or "Unknown"
end

-- Parse lpac error message and provide user-friendly description
function M.get_friendly_error(error_msg)
	if not error_msg or type(error_msg) ~= "string" then
		return "Unknown error occurred"
	end

	local error_map = {
		-- PC/SC errors
		["SCardEstablishContext() failed: 8010001D"] =
			"PC/SC service not running. Please install and start pcscd daemon.",
		["SCardEstablishContext() failed"] =
			"Failed to connect to PC/SC service. Check if pcscd is running.",
		["SCardListReaders() failed"] =
			"No card readers found. Check USB connections or PC/SC configuration.",

		-- eUICC initialization errors
		["es10c_euicc_init error: -1"] =
			"Failed to initialize eUICC. Check custom ISD-R AID in settings.",
		["es10c_euicc_init error"] =
			"eUICC initialization failed. Verify hardware connection.",

		-- Network/SM-DP+ errors
		["es9p_error: 8.1"] =
			"SM-DP+ server error. The server refused the request.",
		["es9p_error: 8.1/3.8"] =
			"Matching ID not found on SM-DP+ server.",
		["es9p_error: 8.2/2.2"] =
			"Invalid or incorrect confirmation code.",
		["es9p_error: 8.2"] =
			"Profile download error. Check activation code or confirmation code.",

		-- HTTP/Network errors
		["curl_easy_perform() failed"] =
			"Network connection failed. Check internet connectivity.",
		["HTTP error"] =
			"HTTP request failed. Check network connection.",

		-- Profile operation errors
		["profile not found"] =
			"Profile not found. It may have been deleted.",
		["profile already enabled"] =
			"Profile is already enabled.",
		["profile already disabled"] =
			"Profile is already disabled.",
		["profile not in disabled state"] =
			"Profile must be disabled before it can be deleted. Please disable it first.",

		-- QMI errors
		["QMI error"] =
			"QMI communication error. Check modem connection.",

		-- MBIM errors
		["MBIM error"] =
			"MBIM communication error. Check modem connection.",
	}

	-- Check for exact match
	if error_map[error_msg] then
		return error_map[error_msg]
	end

	-- Check for partial match
	for pattern, friendly_msg in pairs(error_map) do
		if error_msg:find(pattern, 1, true) then
			return friendly_msg
		end
	end

	-- Return original error if no match found
	return error_msg
end

-- Check if lpac command succeeded
function M.is_success(result)
	if not result or type(result) ~= "table" then
		return false
	end

	if not result.payload or type(result.payload) ~= "table" then
		return false
	end

	return result.payload.code == 0
end

-- Get error message from lpac result
function M.get_error_message(result)
	if not result or type(result) ~= "table" then
		return "Invalid result"
	end

	-- Check data field first (most specific error info from lpac)
	if result.payload and result.payload.data and type(result.payload.data) == "string" then
		return M.get_friendly_error(result.payload.data)
	end

	if result.payload and result.payload.message then
		return M.get_friendly_error(result.payload.message)
	end

	if result.payload and result.payload.raw_output then
		return M.get_friendly_error(result.payload.raw_output)
	end

	return "Unknown error"
end

-- Format bytes to human-readable size
function M.format_bytes(bytes)
	if not bytes or type(bytes) ~= "number" then
		return "0 B"
	end

	if bytes < 1024 then
		return string.format("%d B", bytes)
	elseif bytes < 1024 * 1024 then
		return string.format("%.1f KB", bytes / 1024)
	else
		return string.format("%.1f MB", bytes / (1024 * 1024))
	end
end

-- Parse activation code into components
function M.parse_activation_code(code)
	if not code or type(code) ~= "string" then
		return nil
	end

	-- Check format
	if not code:match("^LPA:1%$") then
		return nil
	end

	local parts = {}
	for part in code:gmatch("[^$]+") do
		table.insert(parts, part)
	end

	if #parts < 3 then
		return nil
	end

	local result = {
		version = parts[1],  -- "LPA:1"
		smdp = parts[2],
		matching_id = parts[3],
		confirmation_code = parts[4] or nil
	}

	return result
end

-- Check if a string is empty or nil
function M.is_empty(str)
	return not str or str == "" or str:match("^%s*$") ~= nil
end

-- Trim whitespace from string
function M.trim(str)
	if not str or type(str) ~= "string" then
		return ""
	end
	return str:match("^%s*(.-)%s*$")
end

-- Split string by delimiter
function M.split(str, delimiter)
	local result = {}
	if not str or type(str) ~= "string" then
		return result
	end

	delimiter = delimiter or ","

	for part in str:gmatch("[^" .. delimiter .. "]+") do
		table.insert(result, M.trim(part))
	end

	return result
end

-- Get current timestamp
function M.get_timestamp()
	return os.time()
end

-- Format timestamp to readable date
function M.format_date(timestamp)
	if not timestamp or type(timestamp) ~= "number" then
		return "N/A"
	end

	return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

-- Generate a simple operation cooldown checker
-- Returns: can_proceed (bool), remaining_seconds (number)
function M.check_cooldown(last_time, cooldown_seconds)
	cooldown_seconds = cooldown_seconds or 60

	if not last_time or type(last_time) ~= "number" then
		return true, 0
	end

	local now = os.time()
	local elapsed = now - last_time

	if elapsed >= cooldown_seconds then
		return true, 0
	else
		return false, cooldown_seconds - elapsed
	end
end

-- Validate SM-DP+ address format
function M.validate_smdp_address(address)
	if not address or type(address) ~= "string" then
		return false, "SM-DP+ address must be a string"
	end

	-- Basic domain name validation
	if not address:match("^[%w%.%-]+%.[%w]+$") then
		return false, "Invalid SM-DP+ address format"
	end

	return true
end

-- Validate matching ID format
function M.validate_matching_id(matching_id)
	if not matching_id or type(matching_id) ~= "string" then
		return false, "Matching ID must be a string"
	end

	if #matching_id == 0 then
		return false, "Matching ID cannot be empty"
	end

	-- Matching ID can contain alphanumeric characters and hyphens
	if not matching_id:match("^[%w%-]+$") then
		return false, "Matching ID contains invalid characters"
	end

	return true
end

-- Validate confirmation code format
function M.validate_confirmation_code(code)
	if not code or type(code) ~= "string" then
		return false, "Confirmation code must be a string"
	end

	if #code == 0 then
		return true  -- Empty confirmation code is valid (optional)
	end

	-- Confirmation code is typically alphanumeric
	if not code:match("^[%w%-]+$") then
		return false, "Confirmation code contains invalid characters"
	end

	return true
end

-- Create a result object for API responses
function M.create_result(success, message, data)
	return {
		success = success,
		message = message or "",
		data = data or nil
	}
end

-- Logging function with syslog support
-- @param level string Log level (DEBUG, INFO, ERROR)
-- @param message string Log message
function M.log(level, message)
	-- Use nixio.syslog for logging
	local ok, syslog = pcall(require, "nixio.syslog")
	if ok and syslog then
		pcall(function()
			syslog.openlog("luci-lpac", "pid", "daemon")
			local priority = (level == "ERROR" and "err") or (level == "INFO" and "info") or "debug"
			syslog.syslog(priority, "[" .. level .. "] " .. tostring(message))
		end)
	end
end

return M
