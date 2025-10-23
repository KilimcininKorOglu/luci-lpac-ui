// dashboard.js - Dashboard view for luci-app-lpac
// Copyright (C) 2025
// Licensed under GPL-3.0

'use strict';
'require view';
'require request';
'require ui';

return view.extend({
	load: function() {
		return Promise.all([
			request.get('/cgi-bin/luci/admin/network/lpac/api/dashboard_summary'),
			request.get('/cgi-bin/luci/admin/network/lpac/api/check_lpac')
		]);
	},

	render: function(data) {
		// Parse JSON responses from responseText
		var summaryResponse = data[0] ? JSON.parse(data[0].responseText || '{}') : {};
		var lpacCheckResponse = data[1] ? JSON.parse(data[1].responseText || '{}') : {};

		var summary = (summaryResponse && summaryResponse.data) ? summaryResponse.data : {};
		var lpacAvailable = (lpacCheckResponse && lpacCheckResponse.success && lpacCheckResponse.data && lpacCheckResponse.data.installed) ? true : false;

		// Status badge helper
		var createStatusBadge = function(status, text) {
			var badgeClass = 'badge ';
			if (status === 'success' || status === 'connected') {
				badgeClass += 'badge-success';
			} else if (status === 'warning') {
				badgeClass += 'badge-warning';
			} else if (status === 'error' || status === 'disconnected') {
				badgeClass += 'badge-danger';
			} else {
				badgeClass += 'badge-secondary';
			}
			return E('span', { 'class': badgeClass }, text);
		};

		var container = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('eSIM Management Dashboard')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Overview of your eSIM/eUICC status and profiles'))
		]);

		// lpac availability check
		if (!lpacAvailable) {
			container.appendChild(E('div', { 'class': 'alert-message warning' }, [
				E('h4', {}, _('lpac Not Installed')),
				E('p', {}, _('The lpac binary is not installed or not executable. Please install lpac package first.'))
			]));
			return container;
		}

		// eUICC Chip Status Section
		var chipStatus = summary.chip_status || 'disconnected';
		var chipStatusText = chipStatus === 'connected' ? _('Connected') : _('Disconnected');

		var chipSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '📱 ' + _('eUICC Chip Status'))
		]);

		var chipRows = [];

		// Status row
		chipRows.push(E('tr', {}, [
			E('td', {}, _('Status')),
			E('td', {}, createStatusBadge(chipStatus, chipStatusText))
		]));

		// EID row
		if (summary.eid) {
			chipRows.push(E('tr', {}, [
				E('td', {}, _('EID')),
				E('td', {}, E('code', {}, summary.eid))
			]));
		} else {
			chipRows.push(E('tr', {}, [
				E('td', {}, _('EID')),
				E('td', { 'class': 'text-muted' }, _('Not available'))
			]));
		}

		// Firmware row
		if (summary.firmware_version) {
			chipRows.push(E('tr', {}, [
				E('td', {}, _('Firmware Version')),
				E('td', {}, summary.firmware_version)
			]));
		}

		// Free Memory row
		if (summary.free_memory !== null && summary.free_memory !== undefined) {
			var memoryText = summary.free_memory < 1024 ?
				summary.free_memory + ' KB' :
				(summary.free_memory / 1024).toFixed(1) + ' MB';
			chipRows.push(E('tr', {}, [
				E('td', {}, _('Free Memory')),
				E('td', {}, memoryText)
			]));
		}

		// Profiles count row
		if (summary.profiles_total !== null && summary.profiles_total !== undefined) {
			chipRows.push(E('tr', {}, [
				E('td', {}, _('Profiles')),
				E('td', {}, String(summary.profiles_enabled || 0) + '/' + String(summary.profiles_total || 0) + ' ' + _('active'))
			]));
		}

		chipSection.appendChild(E('table', { 'class': 'table' }, [
			E('tbody', {}, chipRows)
		]));

		container.appendChild(chipSection);

		// Profile Summary Section
		var profileSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '📋 ' + _('Profile Summary'))
		]);

		var profileRows = [
			E('tr', {}, [
				E('td', {}, _('Total Profiles')),
				E('td', {}, E('strong', {}, String(summary.profiles_total || 0)))
			]),
			E('tr', {}, [
				E('td', {}, _('Enabled')),
				E('td', {}, [
					createStatusBadge('success', '●'),
					' ',
					E('strong', {}, String(summary.profiles_enabled || 0))
				])
			]),
			E('tr', {}, [
				E('td', {}, _('Disabled')),
				E('td', {}, [
					createStatusBadge('error', '●'),
					' ',
					E('strong', {}, String(summary.profiles_disabled || 0))
				])
			])
		];

		profileSection.appendChild(E('table', { 'class': 'table' }, [
			E('tbody', {}, profileRows)
		]));

		container.appendChild(profileSection);

		// Notifications Section
		var notificationCount = summary.notifications_pending || 0;
		var notificationBadge = notificationCount > 0 ?
			createStatusBadge('warning', String(notificationCount)) :
			createStatusBadge('success', '0');

		var notificationSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '🔔 ' + _('Notifications'))
		]);

		var notificationRows = [
			E('tr', {}, [
				E('td', {}, _('Pending Notifications')),
				E('td', {}, notificationBadge)
			]),
			E('tr', {}, [
				E('td', {}, _('Status')),
				E('td', {}, notificationCount > 0 ?
					E('span', { 'class': 'text-warning' }, _('You have pending notifications that require attention.')) :
					E('span', { 'class': 'text-muted' }, _('No pending notifications.')))
			])
		];

		notificationSection.appendChild(E('table', { 'class': 'table' }, [
			E('tbody', {}, notificationRows)
		]));

		container.appendChild(notificationSection);

		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
