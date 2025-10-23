// chip.js - Chip information view for luci-app-lpac
// Copyright (C) 2025
// Licensed under GPL-3.0

'use strict';
'require view';
'require request';
'require ui';

return view.extend({
	load: function() {
		return Promise.all([
			request.get('/cgi-bin/luci/admin/services/lpac/api/chip_info'),
			request.get('/cgi-bin/luci/admin/services/lpac/api/check_lpac')
		]);
	},

	render: function(data) {
		var chipResponse = data[0];
		var lpacCheckResponse = data[1];

		var chipData = (chipResponse && chipResponse.data) ? chipResponse.data : {};
		var lpacAvailable = (lpacCheckResponse && lpacCheckResponse.data && lpacCheckResponse.data.installed) ? true : false;

		var content = [];

		// lpac availability check
		if (!lpacAvailable) {
			content.push(E('div', { 'class': 'alert-message warning' }, [
				E('h4', {}, _('lpac Not Installed')),
				E('p', {}, _('The lpac binary is not installed or not executable. Please install lpac package first.'))
			]));
			return E('div', { 'class': 'cbi-map' }, [
				E('h2', {}, _('eUICC Chip Information')),
				content
			]);
		}

		// Error handling
		if (!chipResponse || !chipResponse.success) {
			content.push(E('div', { 'class': 'alert-message error' }, [
				E('h4', {}, _('Failed to Get Chip Information')),
				E('p', {}, chipResponse ? chipResponse.message : _('Unknown error occurred'))
			]));
			return E('div', { 'class': 'cbi-map' }, [
				E('h2', {}, _('eUICC Chip Information')),
				content
			]);
		}

		// EID Section
		if (chipData.eid) {
			content.push(E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, '📱 ' + _('eUICC Identifier (EID)')),
				E('div', { 'class': 'cbi-value' }, [
					E('code', { 'style': 'font-size: 14px; padding: 8px; background: #f5f5f5; display: block' },
						chipData.eid)
				])
			]));
		}

		// Platform Information
		if (chipData.platformType || chipData.platformVersion || chipData.platformLabel) {
			var platformRows = [];

			if (chipData.platformType) {
				platformRows.push(E('tr', {}, [
					E('td', { 'style': 'width: 30%; font-weight: bold' }, _('Platform Type')),
					E('td', {}, chipData.platformType)
				]));
			}

			if (chipData.platformVersion) {
				platformRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('Platform Version')),
					E('td', {}, chipData.platformVersion)
				]));
			}

			if (chipData.platformLabel) {
				platformRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('Platform Label')),
					E('td', {}, chipData.platformLabel)
				]));
			}

			content.push(E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, '🖥️ ' + _('Platform Information')),
				E('table', { 'class': 'table' }, platformRows)
			]));
		}

		// euiccInfo2 Section
		if (chipData.euiccInfo2) {
			var info2 = chipData.euiccInfo2;
			var euiccRows = [];

			if (info2.profileVersion) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'width: 30%; font-weight: bold' }, _('Profile Version')),
					E('td', {}, info2.profileVersion)
				]));
			}

			if (info2.svn) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('Security Version Number (SVN)')),
					E('td', {}, info2.svn)
				]));
			}

			if (info2.euiccFirmwareVer) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('Firmware Version')),
					E('td', {}, info2.euiccFirmwareVer)
				]));
			}

			if (info2.extCardResource) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('Extended Card Resource')),
					E('td', {}, info2.extCardResource)
				]));
			}

			if (info2.uiccCapability) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('UICC Capability')),
					E('td', {}, info2.uiccCapability)
				]));
			}

			if (info2.javacardVersion) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('JavaCard Version')),
					E('td', {}, info2.javacardVersion)
				]));
			}

			if (info2.globalplatformVersion) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('GlobalPlatform Version')),
					E('td', {}, info2.globalplatformVersion)
				]));
			}

			if (info2.rspCapability) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('RSP Capability')),
					E('td', {}, info2.rspCapability)
				]));
			}

			if (info2.euiccCiPKIdListForVerification && info2.euiccCiPKIdListForVerification.length > 0) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('CI PKI IDs')),
					E('td', {}, info2.euiccCiPKIdListForVerification.join(', '))
				]));
			}

			if (info2.euiccCiPKIdListForSigning && info2.euiccCiPKIdListForSigning.length > 0) {
				euiccRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('Signing PKI IDs')),
					E('td', {}, info2.euiccCiPKIdListForSigning.join(', '))
				]));
			}

			if (euiccRows.length > 0) {
				content.push(E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, '🔧 ' + _('eUICC Information')),
					E('table', { 'class': 'table' }, euiccRows)
				]));
			}
		}

		// Capabilities Section
		if (chipData.capabilities) {
			var caps = chipData.capabilities;
			var capRows = [];

			if (caps.supportedProfiles !== undefined) {
				capRows.push(E('tr', {}, [
					E('td', { 'style': 'width: 30%; font-weight: bold' }, _('Maximum Profiles')),
					E('td', {}, String(caps.supportedProfiles))
				]));
			}

			if (caps.freeMemory !== undefined) {
				var memoryKB = caps.freeMemory;
				var memoryFormatted = memoryKB < 1024 ?
					memoryKB + ' KB' :
					(memoryKB / 1024).toFixed(1) + ' MB';

				capRows.push(E('tr', {}, [
					E('td', { 'style': 'font-weight: bold' }, _('Free Memory')),
					E('td', {}, memoryFormatted)
				]));
			}

			if (capRows.length > 0) {
				content.push(E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, '📊 ' + _('Capabilities')),
					E('table', { 'class': 'table' }, capRows)
				]));
			}
		}

		// If no data at all
		if (content.length === 0) {
			content.push(E('div', { 'class': 'alert-message warning' }, [
				E('h4', {}, _('No Chip Information Available')),
				E('p', {}, _('Unable to retrieve chip information. Please check if the eUICC chip is properly connected.'))
			]));
		}

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('eUICC Chip Information')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Detailed information about your eUICC chip hardware and capabilities')),
			content
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
