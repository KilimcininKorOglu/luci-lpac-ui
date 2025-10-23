// settings.js - Settings view for luci-app-lpac
// Copyright (C) 2025
// Licensed under GPL-3.0

'use strict';
'require view';
'require request';
'require ui';
'require form';

return view.extend({
	load: function() {
		return Promise.all([
			request.get('/cgi-bin/luci/admin/network/lpac/api/get_config'),
			request.get('/cgi-bin/luci/admin/network/lpac/api/list_apdu_drivers'),
			request.get('/cgi-bin/luci/admin/network/lpac/api/check_lpac')
		]);
	},

	render: function(data) {
		var configResponse = data[0];
		var driversResponse = data[1];
		var lpacCheckResponse = data[2];

		var config = (configResponse && configResponse.data) ? configResponse.data : {};
		var drivers = (driversResponse && driversResponse.data && driversResponse.data.drivers) ?
			driversResponse.data.drivers : [];
		var lpacAvailable = (lpacCheckResponse && lpacCheckResponse.data &&
			lpacCheckResponse.data.installed) ? true : false;

		var container = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('lpac Settings')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Configure lpac eSIM management settings'))
		]);

		// lpac availability check
		if (!lpacAvailable) {
			container.appendChild(E('div', { 'class': 'alert-message warning' }, [
				E('h4', {}, _('lpac Not Installed')),
				E('p', {}, _('The lpac binary is not installed or not executable. Please install lpac package first.'))
			]));
			return container;
		}

		// Form elements
		var apduDriverSelect;
		var defaultSmdpInput;

		// Helper: Save configuration
		var saveConfig = function() {
			var newConfig = {
				apdu_driver: apduDriverSelect.value,
				default_smdp: defaultSmdpInput.value.trim()
			};

			ui.showModal(_('Saving Settings'), [
				E('p', { 'class': 'spinning' }, _('Please wait...'))
			]);

			request.post('/cgi-bin/luci/admin/network/lpac/api/update_config', newConfig)
				.then(function(response) {
					ui.hideModal();
					if (response && response.success) {
						ui.addNotification(null,
							E('p', {}, _('Settings saved successfully')), 'info');
					} else {
						ui.addNotification(null,
							E('p', {}, _('Failed to save settings: ') +
								(response ? response.message : _('Unknown error'))), 'error');
					}
				})
				.catch(function(err) {
					ui.hideModal();
					ui.addNotification(null,
						E('p', {}, _('Error saving settings: ') + err.message), 'error');
				});
		};

		// Settings section
		var settingsSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '⚙️ ' + _('lpac Configuration'))
		]);

		// APDU Driver field
		var driverOptions = drivers.map(function(driver) {
			return E('option', {
				'value': driver,
				'selected': driver === config.apdu_driver ? 'selected' : null
			}, driver);
		});

		// If no drivers or current driver not in list, add "auto" option
		if (drivers.length === 0 || (!config.apdu_driver || drivers.indexOf(config.apdu_driver) === -1)) {
			driverOptions.unshift(E('option', {
				'value': 'auto',
				'selected': !config.apdu_driver || config.apdu_driver === 'auto' ? 'selected' : null
			}, _('Auto-detect')));
		}

		settingsSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('APDU Driver')),
			E('div', { 'class': 'cbi-value-field' }, [
				apduDriverSelect = E('select', { 'class': 'cbi-input-select' }, driverOptions),
				E('div', { 'class': 'cbi-value-description' },
					_('Select the APDU interface driver for communicating with the eUICC chip'))
			])
		]));

		// Default SM-DP+ field
		settingsSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Default SM-DP+ Server')),
			E('div', { 'class': 'cbi-value-field' }, [
				defaultSmdpInput = E('input', {
					'type': 'text',
					'class': 'cbi-input-text',
					'value': config.default_smdp || '',
					'placeholder': 'smdp.example.com'
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('Optional default SM-DP+ server address for profile discovery'))
			])
		]));

		// Save button
		settingsSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, ' '),
			E('div', { 'class': 'cbi-value-field' }, [
				E('button', {
					'class': 'btn cbi-button-action',
					'click': saveConfig
				}, _('Save Settings'))
			])
		]));

		container.appendChild(settingsSection);

		// Advanced section
		var advancedSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '🔧 ' + _('Advanced Operations'))
		]);

		// Discover profiles button
		advancedSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Profile Discovery')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('button', {
					'class': 'btn cbi-button',
					'click': function() {
						ui.showModal(_('Discover Profiles'), [
							E('p', {}, _('Discover available profiles from the default SM-DS server?')),
							E('div', { 'class': 'alert-message warning' }, [
								E('p', {}, _('This will contact the SM-DS server and retrieve available profile information.'))
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
										ui.showModal(_('Discovering Profiles'), [
											E('p', { 'class': 'spinning' }, _('Please wait...'))
										]);

										request.post('/cgi-bin/luci/admin/network/lpac/api/discover_profiles', {})
											.then(function(response) {
												ui.hideModal();
												if (response && response.success) {
													var profiles = response.data && response.data.profiles ?
														response.data.profiles : [];
													ui.showModal(_('Discovery Results'), [
														E('p', {}, _('Found ') + profiles.length + _(' available profile(s)')),
														profiles.length > 0 ?
															E('ul', {}, profiles.map(function(p) {
																return E('li', {}, p);
															})) :
															E('p', { 'class': 'text-muted' }, _('No profiles available for download')),
														E('div', { 'class': 'right' }, [
															E('button', {
																'class': 'btn cbi-button-action',
																'click': function() {
																	ui.hideModal();
																}
															}, _('Close'))
														])
													]);
												} else {
													ui.addNotification(null,
														E('p', {}, _('Failed to discover profiles: ') +
															(response ? response.message : _('Unknown error'))), 'error');
												}
											})
											.catch(function(err) {
												ui.hideModal();
												ui.addNotification(null,
													E('p', {}, _('Error discovering profiles: ') + err.message), 'error');
											});
									}
								}, _('Discover'))
							])
						]);
					}
				}, _('Discover Profiles')),
				E('div', { 'class': 'cbi-value-description' },
					_('Search for available profiles on the SM-DS server'))
			])
		]));

		// Factory reset button
		advancedSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Factory Reset')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('button', {
					'class': 'btn cbi-button-negative',
					'click': function() {
						var confirmInput;
						ui.showModal(_('Factory Reset eUICC'), [
							E('div', { 'class': 'alert-message error' }, [
								E('h4', {}, '⚠️ ' + _('DANGER: Factory Reset')),
								E('p', {}, _('This will PERMANENTLY DELETE ALL PROFILES and reset the eUICC to factory state.')),
								E('p', {}, _('This action CANNOT BE UNDONE!'))
							]),
							E('div', { 'class': 'cbi-value' }, [
								E('label', { 'class': 'cbi-value-title' }, _('Confirmation')),
								E('div', { 'class': 'cbi-value-field' }, [
									confirmInput = E('input', {
										'type': 'text',
										'class': 'cbi-input-text',
										'placeholder': _('Type RESET to confirm')
									}),
									E('div', { 'class': 'cbi-value-description' },
										_('Type "RESET" in capital letters to confirm'))
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
									'class': 'btn cbi-button-negative',
									'click': function() {
										var confirmation = confirmInput.value.trim();
										if (confirmation !== 'RESET') {
											ui.addNotification(null,
												E('p', {}, _('Invalid confirmation. Type "RESET" exactly.')), 'error');
											return;
										}

										ui.showModal(_('Factory Resetting eUICC'), [
											E('p', { 'class': 'spinning' }, _('Please wait, this may take several minutes...')),
											E('p', {}, _('Do not disconnect the eUICC during this operation.'))
										]);

										request.post('/cgi-bin/luci/admin/network/lpac/api/factory_reset', {
											confirmation: confirmation
										})
											.then(function(response) {
												ui.hideModal();
												if (response && response.success) {
													ui.showModal(_('Factory Reset Complete'), [
														E('div', { 'class': 'alert-message success' }, [
															E('p', {}, '✓ ' + _('eUICC has been reset to factory state')),
															E('p', {}, _('All profiles have been deleted.'))
														]),
														E('div', { 'class': 'right' }, [
															E('button', {
																'class': 'btn cbi-button-action',
																'click': function() {
																	window.location.href = L.url('admin', 'network', 'lpac', 'dashboard');
																}
															}, _('Go to Dashboard'))
														])
													]);
												} else {
													ui.addNotification(null,
														E('p', {}, _('Failed to reset eUICC: ') +
															(response ? response.message : _('Unknown error'))), 'error');
												}
											})
											.catch(function(err) {
												ui.hideModal();
												ui.addNotification(null,
													E('p', {}, _('Error resetting eUICC: ') + err.message), 'error');
											});
									}
								}, _('Factory Reset'))
							])
						]);

						setTimeout(function() {
							confirmInput.focus();
						}, 100);
					}
				}, _('Factory Reset eUICC')),
				E('div', { 'class': 'cbi-value-description' },
					_('⚠️ Permanently delete all profiles and reset eUICC to factory state'))
			])
		]));

		container.appendChild(advancedSection);

		// Help section
		var helpSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '❓ ' + _('Help')),
			E('p', {}, E('strong', {}, _('APDU Driver:'))),
			E('p', {}, _('The APDU driver controls how lpac communicates with the eUICC chip. Common drivers include:')),
			E('ul', {}, [
				E('li', {}, E('strong', {}, 'auto: ') + _('Automatically detect the best driver')),
				E('li', {}, E('strong', {}, 'stdio: ') + _('Standard input/output interface')),
				E('li', {}, E('strong', {}, 'at: ') + _('AT command interface for modems')),
				E('li', {}, E('strong', {}, 'qmi_qrtr: ') + _('Qualcomm MSM Interface'))
			]),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Default SM-DP+ Server:'))),
			E('p', {}, _('Setting a default SM-DP+ server allows automatic profile discovery without manually entering the server address each time.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Factory Reset:'))),
			E('p', {}, _('Factory reset permanently erases all eSIM profiles and returns the eUICC to its original state. Use this only if absolutely necessary.'))
		]);

		container.appendChild(helpSection);

		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
