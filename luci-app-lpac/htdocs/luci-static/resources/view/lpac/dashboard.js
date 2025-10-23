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
			E('strong', {}, _('Status')),
			E('div', { 'style': 'margin-top: 5px' }, createStatusBadge(chipStatus, chipStatusText))
			]),
		summary.eid ? E('div', {}, [
			E('strong', {}, _('EID')),
			E('div', { 'style': 'margin-top: 5px' }, E('code', {}, summary.eid))
		]) : E('div', { 'class': 'text-muted' }, _('EID not available'))
		], '📱'));

		// Profiles Summary Card
		content.push(createCard(_('Profile Summary'), [
			E('div', { 'style': 'margin-bottom: 10px' }, [
				E('strong', {}, _('Total Profiles')),
				E('div', { 'style': 'margin-top: 5px; font-weight: bold' }, String(summary.profiles_total || 0))
			]),
			E('div', { 'style': 'margin-bottom: 10px' }, [
				E('strong', {}, _('Enabled')),
				E('div', { 'style': 'margin-top: 5px' }, [
					createStatusBadge('success', '●'),
					' ',
					E('span', { 'style': 'font-weight: bold' }, String(summary.profiles_enabled || 0))
				])
			]),
			E('div', { 'style': 'margin-bottom: 10px' }, [
				E('strong', {}, _('Disabled')),
				E('div', { 'style': 'margin-top: 5px' }, [
					createStatusBadge('error', '●'),
					' ',
					E('span', { 'style': 'font-weight: bold' }, String(summary.profiles_disabled || 0))
				])
			])
		], '📋'));

		// Notifications Card
		var notificationCount = summary.notifications_pending || 0;
		var notificationBadge = notificationCount > 0 ?
			createStatusBadge('warning', String(notificationCount)) :
			createStatusBadge('success', '0');

		content.push(createCard(_('Notifications'), [
			E('div', { 'style': 'margin-bottom: 10px' }, [
			E('strong', {}, _('Pending Notifications')),
			E('div', { 'style': 'margin-top: 5px' }, notificationBadge)
			]),
			notificationCount > 0 ? E('div', { 'class': 'text-warning' },
				_('You have pending notifications that require attention.')) :
				E('div', { 'class': 'text-muted' }, _('No pending notifications.'))
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
