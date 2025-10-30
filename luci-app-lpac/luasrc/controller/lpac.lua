-- Copyright 2025 KilimcininKorOglu
-- https://github.com/KilimcininKorOglu/luci-lpac-ui
-- Licensed under the MIT License

module("luci.controller.lpac", package.seeall)

-- Helper function to get device settings from UCI
-- Uses new lpac UCI format: lpac.global.*, lpac.at.*, lpac.mbim.*, lpac.uqmi.*
local function get_device_settings()
	local uci = require "luci.model.uci".cursor()

	-- New UCI format (lpac 2.3.0+)
	local driver = uci:get("lpac", "global", "apdu_backend") or "at"
	local at_device = uci:get("lpac", "at", "device") or "/dev/ttyUSB2"
	local mbim_device = uci:get("lpac", "mbim", "device") or "/dev/cdc-wdm0"
	local qmi_device = uci:get("lpac", "uqmi", "device") or "/dev/cdc-wdm0"
	local http_client = uci:get("lpac", "global", "http_backend") or "curl"
	local driver_home = "/usr/lib/lpac/driver"  -- Fixed path in new format
	local custom_isd_r_aid = uci:get("lpac", "global", "custom_isd_r_aid") or ""

	return driver, at_device, mbim_device, qmi_device, http_client, driver_home, custom_isd_r_aid
end

-- Helper function to save device settings to UCI
-- Uses new lpac UCI format: lpac.global.*, lpac.at.*, lpac.mbim.*, lpac.uqmi.*
local function save_device_settings(driver, at_device, mbim_device, qmi_device, http_client, driver_home, custom_isd_r_aid)
	local uci = require "luci.model.uci".cursor()

	-- Ensure global section exists
	if not uci:get("lpac", "global") then
		uci:set("lpac", "global", "global")
	end

	-- Save global settings
	uci:set("lpac", "global", "apdu_backend", driver or "at")
	uci:set("lpac", "global", "http_backend", http_client or "curl")
	uci:set("lpac", "global", "apdu_debug", "0")
	uci:set("lpac", "global", "http_debug", "0")

	if custom_isd_r_aid and custom_isd_r_aid ~= "" then
		uci:set("lpac", "global", "custom_isd_r_aid", custom_isd_r_aid)
	else
		uci:set("lpac", "global", "custom_isd_r_aid", "A0000005591010FFFFFFFF8900000100")
	end

	-- Ensure at section exists
	if not uci:get("lpac", "at") then
		uci:set("lpac", "at", "at")
	end
	uci:set("lpac", "at", "device", at_device or "/dev/ttyUSB2")
	uci:set("lpac", "at", "debug", "0")

	-- Ensure uqmi section exists
	if not uci:get("lpac", "uqmi") then
		uci:set("lpac", "uqmi", "uqmi")
	end
	uci:set("lpac", "uqmi", "device", qmi_device or "/dev/cdc-wdm0")
	uci:set("lpac", "uqmi", "debug", "0")

	-- Ensure mbim section exists
	if not uci:get("lpac", "mbim") then
		uci:set("lpac", "mbim", "mbim")
	end
	uci:set("lpac", "mbim", "device", mbim_device or "/dev/cdc-wdm0")
	uci:set("lpac", "mbim", "proxy", "1")

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
	entry({"admin", "network", "lpac", "reconnect_network"}, call("action_reconnect_network"), nil).leaf = true
	entry({"admin", "network", "lpac", "clear_lock"}, call("action_clear_lock"), nil).leaf = true
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
	local driver, at_device, mbim_device, qmi_device, http_client, driver_home, custom_isd_r_aid = get_device_settings()
	driver = http.formvalue("driver") or driver
	at_device = http.formvalue("at_device") or at_device
	mbim_device = http.formvalue("mbim_device") or mbim_device
	qmi_device = http.formvalue("qmi_device") or qmi_device

	-- Build command with environment variables
	local env_vars = string.format("LPAC_DRIVER_HOME=%s ", util.shellquote(driver_home))
	if custom_isd_r_aid and custom_isd_r_aid ~= "" then
		env_vars = env_vars .. string.format("CUSTOM_ISD_R_AID=%s ", util.shellquote(custom_isd_r_aid))
	end

	-- Build command with device options
	local cmd = string.format("%s/usr/bin/lpac_json -d %s", env_vars, util.shellquote(driver))

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

	local driver, at_device, mbim_device, qmi_device, http_client, driver_home, custom_isd_r_aid = get_device_settings()

	http.prepare_content("application/json")
	http.write_json({
		success = true,
		driver = driver,
		at_device = at_device,
		mbim_device = mbim_device,
		qmi_device = qmi_device,
		http_client = http_client,
		driver_home = driver_home,
		custom_isd_r_aid = custom_isd_r_aid
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
	local driver_home = http.formvalue("driver_home")
	local custom_isd_r_aid = http.formvalue("custom_isd_r_aid")

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

	local success = save_device_settings(driver, at_device, mbim_device, qmi_device, http_client, driver_home, custom_isd_r_aid)

	http.prepare_content("application/json")
	http.write_json({
		success = success,
		driver = driver,
		at_device = at_device,
		mbim_device = mbim_device,
		qmi_device = qmi_device,
		http_client = http_client,
		driver_home = driver_home or "/usr/lib/lpac/driver",
		custom_isd_r_aid = custom_isd_r_aid or "",
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

-- Reconnect network interface (restart QMI/WWAN after profile change)
function action_reconnect_network()
	local http = require "luci.http"
	local util = require "luci.util"
	local uci = require "luci.model.uci".cursor()

	-- Find cellular/QMI interfaces and restart them
	local reconnected = {}
	uci:foreach("network", "interface", function(s)
		local proto = s.proto or ""
		-- Check if interface uses QMI, WWAN, or cellular protocols
		if proto == "qmi" or proto == "ncm" or proto == "mbim" or proto == "3g" or proto == "wwan" then
			local iface = s[".name"]
			util.exec("logger -t lpac 'Reconnecting network interface: " .. iface .. " (proto: " .. proto .. ")'")
			-- Execute ifdown and ifup
			util.exec("ifdown " .. iface .. " 2>&1")
			util.exec("sleep 2")
			util.exec("ifup " .. iface .. " 2>&1")
			table.insert(reconnected, iface)
		end
	end)

	http.prepare_content("application/json")
	if #reconnected > 0 then
		util.exec("logger -t lpac 'Successfully reconnected interfaces: " .. table.concat(reconnected, ", ") .. "'")
		http.write_json({
			success = true,
			message = "Reconnected interfaces: " .. table.concat(reconnected, ", ") .. ". Wait 20-30s for connection."
		})
	else
		http.write_json({
			success = false,
			error = "No cellular/QMI interfaces found. Check your network configuration."
		})
	end
end

-- Clear stale lock file manually and kill all lpac/lpac_json processes
function action_clear_lock()
	local http = require "luci.http"
	local util = require "luci.util"

	-- Kill all lpac-related processes using multiple methods
	-- Method 1: killall with both names
	util.exec("killall -9 lpac 2>&1")
	util.exec("killall -9 lpac-bin 2>&1")
	util.exec("killall lpac_json 2>&1; killall -9 lpac_json 2>&1")

	-- Method 2: pkill for pattern matching (catches processes with lpac in name)
	util.exec("pkill -9 -f lpac 2>&1")

	-- Method 3: Find and kill any remaining processes by searching /proc
	util.exec("ps aux | grep -E '[l]pac|[l]pac-bin|[l]pac_json' | awk '{print $2}' | xargs -r kill -9 2>&1")

	-- Remove the lock file
	local lockfile = "/var/run/lpac_json.lock"
	util.exec("rm -f " .. lockfile .. " 2>&1")
	local lock_exists = util.exec("test -f " .. lockfile .. " && echo 1 || echo 0")

	http.prepare_content("application/json")
	if tonumber(lock_exists) == 0 then
		-- Lock file removed successfully
		util.exec("logger -t lpac_json 'Lock file manually cleared via web UI - killed all lpac, lpac-bin and lpac_json processes'")
		http.write_json({
			success = true,
			message = "Lock cleared and all lpac/lpac-bin/lpac_json processes killed. You can now retry your operation."
		})
	else
		-- Lock file still exists (permission issue?)
		http.write_json({
			success = false,
			error = "Failed to remove lock file. Check system permissions."
		})
	end
end
