-- Copyright 2025 Kerem
-- Licensed under the MIT License

module("luci.controller.lpac", package.seeall)

-- Helper function to get device settings from UCI
local function get_device_settings()
	local uci = require "luci.model.uci".cursor()
	local qmi_device = uci:get("lpac", "device", "qmi_device") or "/dev/cdc-wdm0"
	local serial_device = uci:get("lpac", "device", "serial_device") or ""
	return qmi_device, serial_device
end

-- Helper function to save device settings to UCI
local function save_device_settings(qmi_device, serial_device)
	local uci = require "luci.model.uci".cursor()
	uci:set("lpac", "device", "settings")
	uci:set("lpac", "device", "qmi_device", qmi_device or "/dev/cdc-wdm0")
	uci:set("lpac", "device", "serial_device", serial_device or "")
	uci:commit("lpac")
	return true
end

function index()
	entry({"admin", "network", "lpac"}, alias("admin", "network", "lpac", "profiles"), _("eSIM (LPAC)"), 60).dependent = false
	entry({"admin", "network", "lpac", "profiles"}, template("lpac/profiles"), _("Profile Management"), 1)
	entry({"admin", "network", "lpac", "add"}, call("action_add_profile"), nil).leaf = true
	entry({"admin", "network", "lpac", "delete"}, call("action_delete_profile"), nil).leaf = true
	entry({"admin", "network", "lpac", "list"}, call("action_list_profiles"), nil).leaf = true
	entry({"admin", "network", "lpac", "status"}, call("action_get_status"), nil).leaf = true
	entry({"admin", "network", "lpac", "detect_devices"}, call("action_detect_devices"), nil).leaf = true
	entry({"admin", "network", "lpac", "get_settings"}, call("action_get_settings"), nil).leaf = true
	entry({"admin", "network", "lpac", "save_settings"}, call("action_save_settings"), nil).leaf = true
end

-- Add eSIM Profile
function action_add_profile()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	local activation_code = http.formvalue("activation_code")
	local confirmation_code = http.formvalue("confirmation_code")

	-- Get device settings from UCI (or use form values as override)
	local qmi_device, serial_device = get_device_settings()
	qmi_device = http.formvalue("qmi_device") or qmi_device
	serial_device = http.formvalue("serial_device") or serial_device

	if not activation_code or activation_code == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "Activation code is required"
		})
		return
	end

	-- Build command with wrapper script and device options
	local cmd = string.format("/usr/bin/quectel_lpad_json -q %s", util.shellquote(qmi_device))

	if serial_device ~= "" then
		cmd = cmd .. string.format(" -s %s", util.shellquote(serial_device))
	end

	cmd = cmd .. string.format(" add %s", util.shellquote(activation_code))

	if confirmation_code and confirmation_code ~= "" then
		cmd = cmd .. " " .. util.shellquote(confirmation_code)
	end

	-- Execute command
	local output = util.exec(cmd .. " 2>&1")

	-- Parse JSON output from wrapper
	local result = json.parse(output)

	http.prepare_content("application/json")
	if result then
		http.write_json(result)
	else
		http.write_json({
			success = false,
			error = "Failed to parse response",
			raw_output = output
		})
	end
end

-- Delete eSIM Profile
function action_delete_profile()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	local profile_id = tonumber(http.formvalue("profile_id"))

	-- Get device settings from UCI (or use form values as override)
	local qmi_device, serial_device = get_device_settings()
	qmi_device = http.formvalue("qmi_device") or qmi_device
	serial_device = http.formvalue("serial_device") or serial_device

	if not profile_id or profile_id < 1 or profile_id > 16 then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "Invalid profile ID (1-16)"
		})
		return
	end

	-- Build command with wrapper script and device options
	local cmd = string.format("/usr/bin/quectel_lpad_json -q %s", util.shellquote(qmi_device))

	if serial_device ~= "" then
		cmd = cmd .. string.format(" -s %s", util.shellquote(serial_device))
	end

	cmd = cmd .. string.format(" delete %d", profile_id)

	-- Execute command
	local output = util.exec(cmd .. " 2>&1")

	-- Parse JSON output from wrapper
	local result = json.parse(output)

	http.prepare_content("application/json")
	if result then
		http.write_json(result)
	else
		http.write_json({
			success = false,
			error = "Failed to parse response",
			raw_output = output
		})
	end
end

-- List installed profiles (using wrapper script)
function action_list_profiles()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	-- Get device settings from UCI (or use form values as override)
	local qmi_device, serial_device = get_device_settings()
	qmi_device = http.formvalue("qmi_device") or qmi_device
	serial_device = http.formvalue("serial_device") or serial_device

	-- Build command with device options
	local cmd = string.format("/usr/bin/quectel_lpad_json -q %s", util.shellquote(qmi_device))

	if serial_device ~= "" then
		cmd = cmd .. string.format(" -s %s", util.shellquote(serial_device))
	end

	cmd = cmd .. " list 2>&1"

	local output = util.exec(cmd)

	-- Parse JSON output from wrapper
	local result = json.parse(output)

	http.prepare_content("application/json")
	if result then
		http.write_json(result)
	else
		http.write_json({
			success = false,
			error = "Failed to parse response",
			raw_output = output
		})
	end
end

-- Get modem status
function action_get_status()
	local http = require "luci.http"
	local util = require "luci.util"

	-- Get device settings from UCI (or use form values as override)
	local qmi_device, _ = get_device_settings()
	qmi_device = http.formvalue("qmi_device") or qmi_device

	-- Get modem status
	local cmd = string.format("qmicli -d %s --uim-get-card-status 2>&1", util.shellquote(qmi_device))
	local output = util.exec(cmd)

	-- Check if modem is accessible
	local modem_available = not output:match("error") and not output:match("couldn't find")

	http.prepare_content("application/json")
	http.write_json({
		success = modem_available,
		status = output,
		modem_available = modem_available,
		device = qmi_device
	})
end

-- Detect available modem devices
function action_detect_devices()
	local http = require "luci.http"
	local util = require "luci.util"
	local nixio = require "nixio"
	local fs = require "nixio.fs"

	local devices = {
		qmi_devices = {},
		serial_devices = {}
	}

	-- Detect QMI devices (/dev/cdc-wdm*)
	local qmi_pattern = "/dev/cdc-wdm"
	for i = 0, 9 do
		local dev = qmi_pattern .. i
		if fs.stat(dev, "type") == "chr" then
			-- Check if device is accessible
			local test_cmd = string.format("qmicli -d %s --get-service-version-info 2>&1 || uqmi -d %s --get-versions 2>&1 || rqmi -d %s --get-versions 2>&1", dev, dev, dev)
			local output = util.exec(test_cmd)
			local accessible = not output:match("error opening device") and not output:match("No such file")

			table.insert(devices.qmi_devices, {
				path = dev,
				name = "cdc-wdm" .. i,
				accessible = accessible,
				type = "QMI"
			})
		end
	end

	-- Detect serial/AT devices (/dev/ttyUSB*)
	local serial_pattern = "/dev/ttyUSB"
	for i = 0, 9 do
		local dev = serial_pattern .. i
		if fs.stat(dev, "type") == "chr" then
			-- Try to identify if it's an AT command interface
			local at_test = string.format("echo 'AT' > %s 2>&1", dev)
			local output = util.exec(at_test)
			local accessible = not output:match("Permission denied") and not output:match("No such file")

			table.insert(devices.serial_devices, {
				path = dev,
				name = "ttyUSB" .. i,
				accessible = accessible,
				type = "Serial/AT"
			})
		end
	end

	-- Also check /dev/ttyACM* (some modems use ACM)
	local acm_pattern = "/dev/ttyACM"
	for i = 0, 9 do
		local dev = acm_pattern .. i
		if fs.stat(dev, "type") == "chr" then
			local at_test = string.format("echo 'AT' > %s 2>&1", dev)
			local output = util.exec(at_test)
			local accessible = not output:match("Permission denied") and not output:match("No such file")

			table.insert(devices.serial_devices, {
				path = dev,
				name = "ttyACM" .. i,
				accessible = accessible,
				type = "Serial/AT"
			})
		end
	end

	http.prepare_content("application/json")
	http.write_json({
		success = true,
		qmi_devices = devices.qmi_devices,
		serial_devices = devices.serial_devices,
		total_devices = #devices.qmi_devices + #devices.serial_devices
	})
end

-- Get device settings from UCI
function action_get_settings()
	local http = require "luci.http"

	local qmi_device, serial_device = get_device_settings()

	http.prepare_content("application/json")
	http.write_json({
		success = true,
		qmi_device = qmi_device,
		serial_device = serial_device
	})
end

-- Save device settings to UCI
function action_save_settings()
	local http = require "luci.http"

	local qmi_device = http.formvalue("qmi_device")
	local serial_device = http.formvalue("serial_device")

	if not qmi_device or qmi_device == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "QMI device is required"
		})
		return
	end

	local success = save_device_settings(qmi_device, serial_device)

	http.prepare_content("application/json")
	http.write_json({
		success = success,
		qmi_device = qmi_device,
		serial_device = serial_device,
		message = "Device settings saved to UCI configuration"
	})
end
