-- Copyright 2025 KilimcininKorOglu
-- https://github.com/KilimcininKorOglu/luci-lpac-ui
-- Licensed under the MIT License

module("luci.controller.lpac", package.seeall)

-- Helper function to get device settings from UCI
local function get_device_settings()
	local uci = require "luci.model.uci".cursor()
	local driver = uci:get("lpac", "device", "driver") or "at"
	local at_device = uci:get("lpac", "device", "at_device") or "/dev/ttyUSB2"
	local mbim_device = uci:get("lpac", "device", "mbim_device") or "/dev/cdc-wdm0"
	local qmi_device = uci:get("lpac", "device", "qmi_device") or "/dev/cdc-wdm0"
	local http_client = uci:get("lpac", "device", "http_client") or "curl"
	return driver, at_device, mbim_device, qmi_device, http_client
end

-- Helper function to save device settings to UCI
local function save_device_settings(driver, at_device, mbim_device, qmi_device, http_client)
	local uci = require "luci.model.uci".cursor()
	uci:set("lpac", "device", "settings")
	uci:set("lpac", "device", "driver", driver or "at")
	uci:set("lpac", "device", "at_device", at_device or "/dev/ttyUSB2")
	uci:set("lpac", "device", "mbim_device", mbim_device or "/dev/cdc-wdm0")
	uci:set("lpac", "device", "qmi_device", qmi_device or "/dev/cdc-wdm0")
	uci:set("lpac", "device", "http_client", http_client or "curl")
	uci:commit("lpac")
	return true
end

function index()
	entry({"admin", "network", "lpac"}, alias("admin", "network", "lpac", "profiles"), _("eSIM (LPAC)"), 60).dependent = false
	entry({"admin", "network", "lpac", "profiles"}, template("lpac/profiles"), _("Profile Management"), 1)
	entry({"admin", "network", "lpac", "about"}, template("lpac/about"), _("About"), 2)
	entry({"admin", "network", "lpac", "add"}, call("action_add_profile"), nil).leaf = true
	entry({"admin", "network", "lpac", "delete"}, call("action_delete_profile"), nil).leaf = true
	entry({"admin", "network", "lpac", "list"}, call("action_list_profiles"), nil).leaf = true
	entry({"admin", "network", "lpac", "status"}, call("action_get_status"), nil).leaf = true
	entry({"admin", "network", "lpac", "detect_devices"}, call("action_detect_devices"), nil).leaf = true
	entry({"admin", "network", "lpac", "get_settings"}, call("action_get_settings"), nil).leaf = true
	entry({"admin", "network", "lpac", "save_settings"}, call("action_save_settings"), nil).leaf = true
	entry({"admin", "network", "lpac", "set_nickname"}, call("action_set_nickname"), nil).leaf = true
	entry({"admin", "network", "lpac", "process_notifications"}, call("action_process_notifications"), nil).leaf = true
	entry({"admin", "network", "lpac", "list_notifications"}, call("action_list_notifications"), nil).leaf = true
	entry({"admin", "network", "lpac", "enable"}, call("action_enable_profile"), nil).leaf = true
	entry({"admin", "network", "lpac", "disable"}, call("action_disable_profile"), nil).leaf = true
	entry({"admin", "network", "lpac", "restart_modem"}, call("action_restart_modem"), nil).leaf = true
end

-- Add eSIM Profile
function action_add_profile()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	local input_mode = http.formvalue("input_mode") or "qr"
	local activation_code = http.formvalue("activation_code")
	local smdp_address = http.formvalue("smdp_address")
	local matching_id = http.formvalue("matching_id")
	local confirmation_code = http.formvalue("confirmation_code")
	local imei = http.formvalue("imei")

	-- Get device settings from UCI (or use form values as override)
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	-- Validate based on input mode
	if input_mode == "manual" then
		if not smdp_address or smdp_address == "" then
			http.prepare_content("application/json")
			http.write_json({
				success = false,
				error = "SM-DP+ address is required for manual mode"
			})
			return
		end
		if not matching_id or matching_id == "" then
			http.prepare_content("application/json")
			http.write_json({
				success = false,
				error = "Matching ID is required for manual mode"
			})
			return
		end
	else
		if not activation_code or activation_code == "" then
			http.prepare_content("application/json")
			http.write_json({
				success = false,
				error = "Activation code is required"
			})
			return
		end
	end

	-- Build command with lpac_json wrapper and device options
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	-- qmi_qrtr doesn't need device path
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))

	-- Add profile download parameters based on mode
	if input_mode == "manual" then
		cmd = cmd .. string.format(" add manual %s %s", util.shellquote(smdp_address), util.shellquote(matching_id))
	else
		cmd = cmd .. string.format(" add %s", util.shellquote(activation_code))
	end

	if confirmation_code and confirmation_code ~= "" then
		cmd = cmd .. " " .. util.shellquote(confirmation_code)
	end

	if imei and imei ~= "" then
		cmd = cmd .. " " .. util.shellquote(imei)
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

	local iccid = http.formvalue("iccid")

	-- Get device settings from UCI (or use form values as override)
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	if not iccid or iccid == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "ICCID is required"
		})
		return
	end

	-- Build command with lpac_json wrapper and device options
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))
	cmd = cmd .. string.format(" delete %s", util.shellquote(iccid))

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
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	-- Build command with device options
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))
	cmd = cmd .. " list 2>&1"

	local output = util.exec(cmd)

	-- Send raw JSON output directly
	-- Strip any trailing whitespace that might cause parsing issues
	output = output:gsub("%s+$", "")

	http.prepare_content("application/json")
	http.write(output)
end

-- Get modem/chip status
function action_get_status()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	-- Get device settings from UCI (or use form values as override)
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	-- Build command with lpac_json wrapper to get chip info/status
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))
	cmd = cmd .. " status 2>&1"

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

-- Detect available modem devices
function action_detect_devices()
	local http = require "luci.http"
	local util = require "luci.util"
	local nixio = require "nixio"
	local fs = require "nixio.fs"

	local devices = {
		at_devices = {},
		mbim_devices = {}
	}

	-- Detect AT devices (/dev/ttyUSB*)
	local serial_pattern = "/dev/ttyUSB"
	for i = 0, 9 do
		local dev = serial_pattern .. i
		if fs.stat(dev, "type") == "chr" then
			-- Try to identify if it's an AT command interface
			local at_test = string.format("echo 'AT' > %s 2>&1", dev)
			local output = util.exec(at_test)
			local accessible = not output:match("Permission denied") and not output:match("No such file")

			table.insert(devices.at_devices, {
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

			table.insert(devices.at_devices, {
				path = dev,
				name = "ttyACM" .. i,
				accessible = accessible,
				type = "Serial/AT"
			})
		end
	end

	-- Detect MBIM devices (/dev/cdc-wdm*)
	local mbim_pattern = "/dev/cdc-wdm"
	for i = 0, 9 do
		local dev = mbim_pattern .. i
		if fs.stat(dev, "type") == "chr" then
			-- Check if device is accessible
			local test_cmd = string.format("mbimcli -d %s --query-device-caps 2>&1 || qmicli -d %s --get-service-version-info 2>&1", dev, dev)
			local output = util.exec(test_cmd)
			local accessible = not output:match("error opening device") and not output:match("No such file")

			table.insert(devices.mbim_devices, {
				path = dev,
				name = "cdc-wdm" .. i,
				accessible = accessible,
				type = "MBIM"
			})
		end
	end

	http.prepare_content("application/json")
	http.write_json({
		success = true,
		at_devices = devices.at_devices,
		mbim_devices = devices.mbim_devices,
		total_devices = #devices.at_devices + #devices.mbim_devices
	})
end

-- Get device settings from UCI
function action_get_settings()
	local http = require "luci.http"

	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()

	http.prepare_content("application/json")
	http.write_json({
		success = true,
		driver = driver,
		at_device = at_device,
		mbim_device = mbim_device,
		qmi_device = qmi_device,
		http_client = http_client
	})
end

-- Save device settings to UCI
function action_save_settings()
	local http = require "luci.http"

	local driver = http.formvalue("driver")
	local at_device = http.formvalue("at_device")
	local mbim_device = http.formvalue("mbim_device")
	local qmi_device = http.formvalue("qmi_device")
	local http_client = http.formvalue("http_client")

	if not driver or driver == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "Driver selection is required"
		})
		return
	end

	-- Validate driver
	if driver ~= "at" and driver ~= "at_csim" and driver ~= "mbim" and driver ~= "qmi" and driver ~= "qmi_qrtr" and driver ~= "uqmi" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "Invalid driver. Must be: at, at_csim, mbim, qmi, qmi_qrtr, or uqmi"
		})
		return
	end

	local success = save_device_settings(driver, at_device, mbim_device, qmi_device, http_client)

	http.prepare_content("application/json")
	http.write_json({
		success = success,
		driver = driver,
		at_device = at_device,
		mbim_device = mbim_device,
		qmi_device = qmi_device,
		http_client = http_client,
		message = "Device settings saved to UCI configuration"
	})
end

-- Set Profile Nickname
function action_set_nickname()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	local iccid = http.formvalue("iccid")
	local nickname = http.formvalue("nickname")

	-- Get device settings from UCI (or use form values as override)
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	if not iccid or iccid == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "ICCID is required"
		})
		return
	end

	-- Build command with lpac_json wrapper and device options
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))
	cmd = cmd .. string.format(" nickname %s %s", util.shellquote(iccid), util.shellquote(nickname))

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

-- Process all pending notifications (automatic GSMA compliance)
function action_process_notifications()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	-- Get device settings from UCI (or use form values as override)
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	-- Build command with lpac_json wrapper and device options
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))
	cmd = cmd .. " notification_process_all"

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

-- Enable eSIM Profile
function action_enable_profile()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	local iccid = http.formvalue("iccid")

	-- Get device settings from UCI (or use form values as override)
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	if not iccid or iccid == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "ICCID is required"
		})
		return
	end

	-- Build command with lpac_json wrapper and device options
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))
	cmd = cmd .. string.format(" enable %s", util.shellquote(iccid))

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

-- Disable eSIM Profile
function action_disable_profile()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	local iccid = http.formvalue("iccid")

	-- Get device settings from UCI (or use form values as override)
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	if not iccid or iccid == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "ICCID is required"
		})
		return
	end

	-- Build command with lpac_json wrapper and device options
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))
	cmd = cmd .. string.format(" disable %s", util.shellquote(iccid))

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

-- List Pending Notifications
function action_list_notifications()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	-- Get device settings from UCI (or use form values as override)
	local driver, at_device, mbim_device, qmi_device, http_client = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	-- Build command with lpac_json wrapper and device options
	local cmd = string.format("/usr/bin/lpac_json -d %s", util.shellquote(driver))

	-- Add device paths based on driver type
	if driver == "at" or driver == "at_csim" then
		cmd = cmd .. string.format(" -t %s", util.shellquote(at_device))
	elseif driver == "mbim" then
		cmd = cmd .. string.format(" -m %s", util.shellquote(mbim_device))
	elseif driver == "qmi" or driver == "uqmi" then
		cmd = cmd .. string.format(" -q %s", util.shellquote(qmi_device))
	end

	cmd = cmd .. string.format(" -h %s", util.shellquote(http_client))
	cmd = cmd .. " notification_list"

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

-- Restart Modem (AT+CFUN soft reset)
function action_restart_modem()
	local http = require "luci.http"
	local util = require "luci.util"
	local json = require "luci.jsonc"

	-- Get form parameters
	local driver = http.formvalue("driver")
	local at_device = http.formvalue("at_device")
	local mbim_device = http.formvalue("mbim_device")

	-- Validate driver
	if not driver or driver == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "Driver parameter is required"
		})
		return
	end

	-- Build lpac_json command
	local cmd = string.format("/usr/bin/lpac_json restart_modem %s %s %s",
		util.shellquote(driver),
		util.shellquote(at_device or "/dev/ttyUSB2"),
		util.shellquote(mbim_device or "/dev/cdc-wdm0")
	)

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
