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

		// Create info card
		var createCard = function(title, content, icon) {
			return E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, [
					icon ? E('span', {}, icon + ' ') : '',
					title
				]),
				E('div', { 'class': 'cbi-value' }, content)
			]);
		};

		var content = [];

		// lpac availability check
		if (!lpacAvailable) {
			return E('div', { 'class': 'cbi-map' }, [
				E('h2', {}, _('eSIM Management Dashboard')),
				E('div', { 'class': 'alert-message warning' }, [
					E('h4', {}, _('lpac Not Installed')),
					E('p', {}, _('The lpac binary is not installed or not executable. Please install lpac package first.'))
				])
			]);
		}

		// eUICC Chip Status Card
		var chipStatus = summary.chip_status || 'disconnected';
		var chipStatusText = chipStatus === 'connected' ? _('Connected') : _('Disconnected');

		content.push(createCard(_('eUICC Chip Status'), [
			E('div', { 'style': 'margin-bottom: 10px' }, [
				E('div', {}, [
					E('strong', {}, _('Status: ')),
					createStatusBadge(chipStatus, chipStatusText)
				])
			]),
			summary.eid ? E('div', {}, [
				E('strong', {}, _('EID: ')),
				E('code', {}, summary.eid)
			]) : E('div', { 'class': 'text-muted' }, _('EID not available'))
		], '📱'));

		// Profiles Summary Card
		content.push(createCard(_('Profile Summary'), [
			E('table', { 'class': 'table' }, [
				E('tr', {}, [
					E('td', {}, _('Total Profiles:')),
					E('td', { 'style': 'text-align: right; font-weight: bold' },
						String(summary.profiles_total || 0))
				]),
				E('tr', {}, [
					E('td', {}, [
						createStatusBadge('success', '●'),
						' ' + _('Enabled:')
					]),
					E('td', { 'style': 'text-align: right; font-weight: bold' },
						String(summary.profiles_enabled || 0))
				]),
				E('tr', {}, [
					E('td', {}, [
						createStatusBadge('error', '●'),
						' ' + _('Disabled:')
					]),
					E('td', { 'style': 'text-align: right; font-weight: bold' },
						String(summary.profiles_disabled || 0))
				])
			]),
			E('p', { 'style': 'margin-top: 10px' }, [
				E('a', {
					'href': L.url('admin', 'network', 'lpac', 'profiles'),
					'class': 'btn cbi-button'
				}, _('Manage Profiles'))
			])
		], '📋'));

		// Notifications Card
		var notificationCount = summary.notifications_pending || 0;
		var notificationBadge = notificationCount > 0 ?
			createStatusBadge('warning', String(notificationCount)) :
			createStatusBadge('success', '0');

		content.push(createCard(_('Notifications'), [
			E('p', {}, [
				_('Pending Notifications: '),
				notificationBadge
			]),
			notificationCount > 0 ? E('p', { 'class': 'text-warning' },
				_('You have pending notifications that require attention.')) :
				E('p', { 'class': 'text-muted' }, _('No pending notifications.')),
			E('p', { 'style': 'margin-top: 10px' }, [
				E('a', {
					'href': L.url('admin', 'network', 'lpac', 'notifications'),
					'class': 'btn cbi-button'
				}, _('View Notifications'))
			])
		], '🔔'));

		// Memory Status Card
		if (summary.free_memory !== null && summary.free_memory !== undefined) {
			var memoryKB = summary.free_memory;
			var memoryFormatted = memoryKB < 1024 ?
				memoryKB + ' KB' :
				(memoryKB / 1024).toFixed(1) + ' MB';

			content.push(createCard(_('eUICC Memory'), [
				E('p', {}, [
					E('strong', {}, _('Free Memory: ')),
					memoryFormatted
				]),
				E('p', { 'class': 'text-muted' }, _('Available space for new profiles'))
			], '💾'));
		}

		// Quick Actions Card
		content.push(createCard(_('Quick Actions'), [
			E('div', { 'style': 'display: flex; flex-wrap: wrap; gap: 10px' }, [
				E('a', {
					'href': L.url('admin', 'network', 'lpac', 'download'),
					'class': 'btn cbi-button-action'
				}, _('Download Profile')),
				E('a', {
					'href': L.url('admin', 'network', 'lpac', 'chip'),
					'class': 'btn cbi-button'
				}, _('Chip Info')),
				E('a', {
					'href': L.url('admin', 'network', 'lpac', 'settings'),
					'class': 'btn cbi-button'
				}, _('Settings'))
			])
		], '⚡'));

		// Return with properly spread content array
		var result = [
			E('h2', {}, _('eSIM Management Dashboard')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Overview of your eSIM/eUICC status and profiles'))
		];

		return E('div', { 'class': 'cbi-map' }, result.concat(content));
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
