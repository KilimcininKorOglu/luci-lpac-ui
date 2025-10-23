// profiles.js - Profile management view for luci-app-lpac
// Copyright (C) 2025
// Licensed under GPL-3.0

'use strict';
'require view';
'require request';
'require ui';
'require dom';

return view.extend({
	load: function() {
		return Promise.all([
			request.get('/cgi-bin/luci/admin/services/lpac/api/list_profiles'),
			request.get('/cgi-bin/luci/admin/services/lpac/api/check_lpac')
		]);
	},

	render: function(data) {
		var profilesResponse = data[0];
		var lpacCheckResponse = data[1];

		var profiles = (profilesResponse && profilesResponse.data && profilesResponse.data.profiles) ?
			profilesResponse.data.profiles : [];
		var lpacAvailable = (lpacCheckResponse && lpacCheckResponse.data && lpacCheckResponse.data.installed) ? true : false;

		var container = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('Profile Management')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Manage eSIM profiles on your eUICC chip'))
		]);

		// lpac availability check
		if (!lpacAvailable) {
			container.appendChild(E('div', { 'class': 'alert-message warning' }, [
				E('h4', {}, _('lpac Not Installed')),
				E('p', {}, _('The lpac binary is not installed or not executable. Please install lpac package first.'))
			]));
			return container;
		}

		// Error handling
		if (!profilesResponse || !profilesResponse.success) {
			container.appendChild(E('div', { 'class': 'alert-message error' }, [
				E('h4', {}, _('Failed to Load Profiles')),
				E('p', {}, profilesResponse ? profilesResponse.message : _('Unknown error occurred'))
			]));
			return container;
		}

		// Helper: Create status badge
		var createStatusBadge = function(enabled) {
			if (enabled) {
				return E('span', { 'class': 'badge badge-success' }, _('Enabled'));
			} else {
				return E('span', { 'class': 'badge badge-secondary' }, _('Disabled'));
			}
		};

		// Helper: Refresh profiles
		var refreshProfiles = function() {
			window.location.reload();
		};

		// Helper: Enable profile
		var enableProfile = function(iccid, nickname) {
			ui.showModal(_('Enable Profile'), [
				E('p', {}, _('Are you sure you want to enable this profile?')),
				E('p', {}, [
					E('strong', {}, _('Nickname: ')),
					nickname || _('(unnamed)')
				]),
				E('p', {}, [
					E('strong', {}, _('ICCID: ')),
					E('code', {}, iccid)
				]),
				E('div', { 'class': 'right' }, [
					E('button', {
						'class': 'btn',
						'click': function() {
							ui.hideModal();
						}
					}, _('Cancel')),
					' ',
					E('button', {
						'class': 'btn cbi-button-action',
						'click': function() {
							ui.showModal(_('Enabling Profile'), [
								E('p', { 'class': 'spinning' }, _('Please wait...'))
							]);

							request.post('/cgi-bin/luci/admin/services/lpac/api/enable_profile', {
								iccid: iccid,
								refresh: true
							}).then(function(response) {
								ui.hideModal();
								if (response && response.success) {
									ui.addNotification(null,
										E('p', {}, _('Profile enabled successfully')), 'info');
									refreshProfiles();
								} else {
									ui.addNotification(null,
										E('p', {}, _('Failed to enable profile: ') +
											(response ? response.message : _('Unknown error'))), 'error');
								}
							}).catch(function(err) {
								ui.hideModal();
								ui.addNotification(null,
									E('p', {}, _('Error enabling profile: ') + err.message), 'error');
							});
						}
					}, _('Enable'))
				])
			]);
		};

		// Helper: Disable profile
		var disableProfile = function(iccid, nickname) {
			ui.showModal(_('Disable Profile'), [
				E('p', {}, _('Are you sure you want to disable this profile?')),
				E('p', {}, [
					E('strong', {}, _('Nickname: ')),
					nickname || _('(unnamed)')
				]),
				E('p', {}, [
					E('strong', {}, _('ICCID: ')),
					E('code', {}, iccid)
				]),
				E('div', { 'class': 'right' }, [
					E('button', {
						'class': 'btn',
						'click': function() {
							ui.hideModal();
						}
					}, _('Cancel')),
					' ',
					E('button', {
						'class': 'btn cbi-button-negative',
						'click': function() {
							ui.showModal(_('Disabling Profile'), [
								E('p', { 'class': 'spinning' }, _('Please wait...'))
							]);

							request.post('/cgi-bin/luci/admin/services/lpac/api/disable_profile', {
								iccid: iccid,
								refresh: true
							}).then(function(response) {
								ui.hideModal();
								if (response && response.success) {
									ui.addNotification(null,
										E('p', {}, _('Profile disabled successfully')), 'info');
									refreshProfiles();
								} else {
									ui.addNotification(null,
										E('p', {}, _('Failed to disable profile: ') +
											(response ? response.message : _('Unknown error'))), 'error');
								}
							}).catch(function(err) {
								ui.hideModal();
								ui.addNotification(null,
									E('p', {}, _('Error disabling profile: ') + err.message), 'error');
							});
						}
					}, _('Disable'))
				])
			]);
		};

		// Helper: Delete profile
		var deleteProfile = function(iccid, nickname) {
			ui.showModal(_('Delete Profile'), [
				E('div', { 'class': 'alert-message warning' }, [
					E('h4', {}, '⚠️ ' + _('Warning')),
					E('p', {}, _('This action cannot be undone. The profile will be permanently deleted from the eUICC.'))
				]),
				E('p', {}, [
					E('strong', {}, _('Nickname: ')),
					nickname || _('(unnamed)')
				]),
				E('p', {}, [
					E('strong', {}, _('ICCID: ')),
					E('code', {}, iccid)
				]),
				E('div', { 'class': 'right' }, [
					E('button', {
						'class': 'btn',
						'click': function() {
							ui.hideModal();
						}
					}, _('Cancel')),
					' ',
					E('button', {
						'class': 'btn cbi-button-negative',
						'click': function() {
							ui.showModal(_('Deleting Profile'), [
								E('p', { 'class': 'spinning' }, _('Please wait...'))
							]);

							request.post('/cgi-bin/luci/admin/services/lpac/api/delete_profile', {
								iccid: iccid,
								confirmed: true
							}).then(function(response) {
								ui.hideModal();
								if (response && response.success) {
									ui.addNotification(null,
										E('p', {}, _('Profile deleted successfully')), 'info');
									refreshProfiles();
								} else {
									ui.addNotification(null,
										E('p', {}, _('Failed to delete profile: ') +
											(response ? response.message : _('Unknown error'))), 'error');
								}
							}).catch(function(err) {
								ui.hideModal();
								ui.addNotification(null,
									E('p', {}, _('Error deleting profile: ') + err.message), 'error');
							});
						}
					}, _('Delete'))
				])
			]);
		};

		// Helper: Set nickname
		var setNickname = function(iccid, currentNickname) {
			var inputEl;

			ui.showModal(_('Set Profile Nickname'), [
				E('p', {}, [
					E('strong', {}, _('ICCID: ')),
					E('code', {}, iccid)
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, _('Nickname')),
					E('div', { 'class': 'cbi-value-field' }, [
						inputEl = E('input', {
							'type': 'text',
							'class': 'cbi-input-text',
							'value': currentNickname || '',
							'placeholder': _('Enter nickname'),
							'maxlength': '64'
						})
					])
				]),
				E('div', { 'class': 'right' }, [
					E('button', {
						'class': 'btn',
						'click': function() {
							ui.hideModal();
						}
					}, _('Cancel')),
					' ',
					E('button', {
						'class': 'btn cbi-button-action',
						'click': function() {
							var newNickname = inputEl.value.trim();
							if (!newNickname) {
								ui.addNotification(null,
									E('p', {}, _('Nickname cannot be empty')), 'warning');
								return;
							}

							ui.showModal(_('Setting Nickname'), [
								E('p', { 'class': 'spinning' }, _('Please wait...'))
							]);

							request.post('/cgi-bin/luci/admin/services/lpac/api/set_nickname', {
								iccid: iccid,
								nickname: newNickname
							}).then(function(response) {
								ui.hideModal();
								if (response && response.success) {
									ui.addNotification(null,
										E('p', {}, _('Nickname updated successfully')), 'info');
									refreshProfiles();
								} else {
									ui.addNotification(null,
										E('p', {}, _('Failed to set nickname: ') +
											(response ? response.message : _('Unknown error'))), 'error');
								}
							}).catch(function(err) {
								ui.hideModal();
								ui.addNotification(null,
									E('p', {}, _('Error setting nickname: ') + err.message), 'error');
							});
						}
					}, _('Save'))
				])
			]);

			// Focus input
			setTimeout(function() {
				inputEl.focus();
				inputEl.select();
			}, 100);
		};

		// Profiles section
		var profilesSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '📋 ' + _('Installed Profiles') + ' (' + profiles.length + ')')
		]);

		if (profiles.length === 0) {
			profilesSection.appendChild(E('div', { 'class': 'alert-message' }, [
				E('p', {}, _('No profiles installed on the eUICC.')),
				E('p', {}, [
					_('You can download a new profile from the '),
					E('a', { 'href': L.url('admin', 'services', 'lpac', 'download') }, _('Download')),
					_(' page.')
				])
			]));
		} else {
			// Create profiles table
			var tableRows = profiles.map(function(profile) {
				var nickname = profile.profileNickname || profile.profileName || _('(unnamed)');
				var provider = profile.serviceProviderName || _('Unknown');
				var iccid = profile.iccid || _('Unknown');
				var enabled = profile.profileState === 'enabled';

				// Action buttons
				var actionButtons = E('div', { 'style': 'display: flex; gap: 5px; flex-wrap: wrap' });

				if (enabled) {
					actionButtons.appendChild(E('button', {
						'class': 'btn cbi-button-neutral',
						'click': function() {
							disableProfile(iccid, nickname);
						}
					}, _('Disable')));
				} else {
					actionButtons.appendChild(E('button', {
						'class': 'btn cbi-button-action',
						'click': function() {
							enableProfile(iccid, nickname);
						}
					}, _('Enable')));
				}

				actionButtons.appendChild(E('button', {
					'class': 'btn cbi-button',
					'click': function() {
						setNickname(iccid, profile.profileNickname);
					}
				}, _('Rename')));

				actionButtons.appendChild(E('button', {
					'class': 'btn cbi-button-negative',
					'click': function() {
						deleteProfile(iccid, nickname);
					}
				}, _('Delete')));

				return E('tr', {}, [
					E('td', { 'style': 'width: 10%; text-align: center' }, createStatusBadge(enabled)),
					E('td', { 'style': 'width: 25%' }, [
						E('strong', {}, nickname),
						E('br'),
						E('small', { 'class': 'text-muted' }, provider)
					]),
					E('td', { 'style': 'width: 30%' }, E('code', { 'style': 'font-size: 11px' }, iccid)),
					E('td', { 'style': 'width: 15%' }, profile.profileClass || _('N/A')),
					E('td', { 'style': 'width: 20%' }, actionButtons)
				]);
			});

			var table = E('table', { 'class': 'table' }, [
				E('thead', {}, [
					E('tr', {}, [
						E('th', { 'style': 'text-align: center' }, _('Status')),
						E('th', {}, _('Profile')),
						E('th', {}, _('ICCID')),
						E('th', {}, _('Class')),
						E('th', {}, _('Actions'))
					])
				]),
				E('tbody', {}, tableRows)
			]);

			profilesSection.appendChild(table);
		}

		// Refresh button
		profilesSection.appendChild(E('div', { 'style': 'margin-top: 15px' }, [
			E('button', {
				'class': 'btn cbi-button',
				'click': refreshProfiles
			}, _('Refresh'))
		]));

		container.appendChild(profilesSection);

		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
