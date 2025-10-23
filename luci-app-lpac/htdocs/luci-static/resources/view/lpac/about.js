// about.js - About page for luci-app-lpac
// Copyright (C) 2025
// Licensed under GPL-3.0

'use strict';
'require view';
'require request';
'require ui';

return view.extend({
	load: function() {
		return Promise.all([
			request.get('/cgi-bin/luci/admin/network/lpac/api/system_info')
		]);
	},

		// Parse JSON response from responseText
		var systemInfoData = data[0] ? JSON.parse(data[0].responseText || '{}') : {};
		var info = (response && response.data) ? response.data : {};
		var info = (systemInfoData && systemInfoData.data) ? systemInfoData.data : {};
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('About luci-app-lpac')),

			// Application Information
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Application Information')),
				E('table', { 'class': 'table' }, [
					E('tr', {}, [
						E('td', { 'style': 'width: 30%; font-weight: bold' }, _('Application')),
						E('td', {}, 'luci-app-lpac')
					]),
					E('tr', {}, [
						E('td', { 'style': 'font-weight: bold' }, _('Version')),
						E('td', {}, info.app_version || '1.0.0')
					]),
					E('tr', {}, [
						E('td', { 'style': 'font-weight: bold' }, _('lpac Version')),
						E('td', {}, info.lpac_version || 'unknown')
					]),
					E('tr', {}, [
						E('td', { 'style': 'font-weight: bold' }, _('License')),
						E('td', {}, 'GPL-3.0')
					]),
					E('tr', {}, [
						E('td', { 'style': 'font-weight: bold' }, _('Repository')),
						E('td', {}, E('a', {
							'href': 'https://github.com/KilimcininKorOglu/luci-lpac-ui',
							'target': '_blank'
						}, 'GitHub'))
					])
				])
			]),

			// System Information
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('System Information')),
				E('table', { 'class': 'table' }, [
					E('tr', {}, [
						E('td', { 'style': 'width: 30%; font-weight: bold' }, _('OpenWrt Version')),
						E('td', {}, info.openwrt_version || 'unknown')
					]),
					E('tr', {}, [
						E('td', { 'style': 'font-weight: bold' }, _('LuCI Version')),
						E('td', {}, info.luci_version || 'unknown')
					])
				])
			]),

			// Credits and Links
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Credits')),
				E('p', {}, _('This application is a web interface for lpac, the eSIM/eUICC profile management tool.')),
				E('p', {}, [
					_('lpac project: '),
					E('a', {
						'href': 'https://github.com/estkme-group/lpac',
						'target': '_blank'
					}, 'https://github.com/estkme-group/lpac')
				]),
				E('p', {}, [
					_('Documentation: '),
					E('a', {
						'href': 'https://github.com/KilimcininKorOglu/luci-lpac-ui/wiki',
						'target': '_blank'
					}, 'Wiki')
				]),
				E('p', {}, [
					_('Report Issues: '),
					E('a', {
						'href': 'https://github.com/KilimcininKorOglu/luci-lpac-ui/issues',
						'target': '_blank'
					}, 'GitHub Issues')
				])
			]),

			// Acknowledgments
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Acknowledgments')),
				E('p', {}, _('Special thanks to:')),
				E('ul', {}, [
					E('li', {}, _('lpac developers for the excellent eSIM management tool')),
					E('li', {}, _('OpenWrt community for the robust platform')),
					E('li', {}, _('LuCI developers for the web framework')),
					E('li', {}, _('All contributors and testers'))
				])
			])
		]);
	}
});
