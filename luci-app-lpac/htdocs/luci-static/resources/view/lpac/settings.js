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
			request.get('/cgi-bin/luci/admin/network/lpac/api/list_http_drivers'),
			request.get('/cgi-bin/luci/admin/network/lpac/api/check_lpac')
		]);
	},

	render: function(data) {
		// Parse JSON responses from responseText
		var configResponse = data[0] ? JSON.parse(data[0].responseText || '{}') : {};
		var apduDriversResponse = data[1] ? JSON.parse(data[1].responseText || '{}') : {};
		var httpDriversResponse = data[2] ? JSON.parse(data[2].responseText || '{}') : {};
		var lpacCheckResponse = data[3] ? JSON.parse(data[3].responseText || '{}') : {};

		var config = (configResponse && configResponse.data) ? configResponse.data : {};
		var apduDrivers = (apduDriversResponse && apduDriversResponse.data && apduDriversResponse.data.drivers) ?
			apduDriversResponse.data.drivers : [];
		var httpDrivers = (httpDriversResponse && httpDriversResponse.data && httpDriversResponse.data.drivers) ?
			httpDriversResponse.data.drivers : [];
		var lpacAvailable = (lpacCheckResponse && lpacCheckResponse.success && lpacCheckResponse.data &&
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
		var httpDriverSelect;
		var defaultSmdpInput;
		var customAidInput;
		var es10xMssInput;
		var qmiSlotInput;
		var pcscReaderInput;
		var autoNotificationCheckbox;
		var debugHttpCheckbox;
		var debugApduCheckbox;
		var logLevelSelect;
		var timeoutInput;
		var downloadCooldownInput;
		var autoManageWwanCheckbox;
		var wwanInterfaceInput;
		var autoSimPowerCycleCheckbox;

		// Helper: Save configuration
		var saveConfig = function() {
			var newConfig = {
				apdu_driver: apduDriverSelect.value,
				http_driver: httpDriverSelect.value,
				default_smdp: defaultSmdpInput.value.trim(),
				custom_aid: customAidInput.value.trim(),
				es10x_mss: parseInt(es10xMssInput.value) || 60,
				qmi_slot: parseInt(qmiSlotInput.value) || 1,
				pcsc_reader: pcscReaderInput.value.trim(),
				auto_notification: autoNotificationCheckbox.checked ? '1' : '0',
				debug_http: debugHttpCheckbox.checked ? '1' : '0',
				debug_apdu: debugApduCheckbox.checked ? '1' : '0',
				log_level: logLevelSelect.value,
				timeout: parseInt(timeoutInput.value) || 120,
				download_cooldown: parseInt(downloadCooldownInput.value) || 60,
				auto_manage_wwan: autoManageWwanCheckbox.checked ? '1' : '0',
				wwan_interface: wwanInterfaceInput.value.trim(),
				auto_sim_power_cycle: autoSimPowerCycleCheckbox.checked ? '1' : '0'
			};

			ui.showModal(_('Saving Settings'), [
				E('p', { 'class': 'spinning' }, _('Please wait...'))
			]);

			request.post('/cgi-bin/luci/admin/network/lpac/api/update_config', newConfig)
				.then(function(xhr) {
					ui.hideModal();
					var response = xhr ? JSON.parse(xhr.responseText || '{}') : {};
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

		// Basic Settings section
		var basicSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '⚙️ ' + _('Basic Configuration'))
		]);

		// APDU Driver field
		var apduDriverOptions = apduDrivers.map(function(driver) {
			return E('option', {
				'value': driver,
				'selected': driver === config.apdu_driver ? 'selected' : null
			}, driver);
		});

		// If no drivers or current driver not in list, add "auto" option
		if (apduDrivers.length === 0 || (!config.apdu_driver || apduDrivers.indexOf(config.apdu_driver) === -1)) {
			apduDriverOptions.unshift(E('option', {
				'value': 'auto',
				'selected': !config.apdu_driver || config.apdu_driver === 'auto' ? 'selected' : null
			}, _('Auto-detect')));
		}

		basicSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('APDU Driver')),
			E('div', { 'class': 'cbi-value-field' }, [
				apduDriverSelect = E('select', { 'class': 'cbi-input-select' }, apduDriverOptions),
				E('div', { 'class': 'cbi-value-description' },
					_('Select the APDU interface driver for communicating with the eUICC chip'))
			])
		]));

		// HTTP Driver field
		var httpDriverOptions = httpDrivers.map(function(driver) {
			return E('option', {
				'value': driver,
				'selected': driver === config.http_driver ? 'selected' : null
			}, driver);
		});

		basicSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('HTTP Driver')),
			E('div', { 'class': 'cbi-value-field' }, [
				httpDriverSelect = E('select', { 'class': 'cbi-input-select' }, httpDriverOptions),
				E('div', { 'class': 'cbi-value-description' },
					_('Select the HTTP interface driver for network communication'))
			])
		]));

		// Default SM-DP+ field
		basicSection.appendChild(E('div', { 'class': 'cbi-value' }, [
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

		// Auto Notification field
		basicSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Auto Notification')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('label', {}, [
					autoNotificationCheckbox = E('input', {
						'type': 'checkbox',
						'checked': config.auto_notification === '1' ? 'checked' : null
					}),
					' ' + _('Enable automatic notification processing')
				]),
				E('div', { 'class': 'cbi-value-description' },
					_('Automatically process pending notifications from SM-DP+ servers'))
			])
		]));

		container.appendChild(basicSection);

		// Hardware-Specific Settings section
		var hardwareSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '🔌 ' + _('Hardware-Specific Settings'))
		]);

		// QMI Slot field
		hardwareSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('QMI Slot')),
			E('div', { 'class': 'cbi-value-field' }, [
				qmiSlotInput = E('input', {
					'type': 'number',
					'class': 'cbi-input-text',
					'value': config.qmi_slot || '1',
					'min': '1',
					'max': '2'
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('QMI slot number for Qualcomm modems (usually 1 or 2)'))
			])
		]));

		// PCSC Reader field
		hardwareSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('PCSC Reader')),
			E('div', { 'class': 'cbi-value-field' }, [
				pcscReaderInput = E('input', {
					'type': 'text',
					'class': 'cbi-input-text',
					'value': config.pcsc_reader || '',
					'placeholder': _('Leave empty for auto-detect')
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('Specify PC/SC reader name (leave empty to auto-detect)'))
			])
		]));

		// Custom AID field
		hardwareSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Custom AID')),
			E('div', { 'class': 'cbi-value-field' }, [
				customAidInput = E('input', {
					'type': 'text',
					'class': 'cbi-input-text',
					'value': config.custom_aid || '',
					'placeholder': 'A0000005591010FFFFFFFF8900000100'
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('Custom Application Identifier for eUICC (leave empty for default)'))
			])
		]));

		// ES10X MSS field
		hardwareSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('ES10X MSS')),
			E('div', { 'class': 'cbi-value-field' }, [
				es10xMssInput = E('input', {
					'type': 'number',
					'class': 'cbi-input-text',
					'value': config.es10x_mss || '60',
					'min': '1',
					'max': '255'
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('ES10X Maximum Segment Size (default: 60)'))
			])
		]));

		container.appendChild(hardwareSection);

		// Debug Options section
		var debugSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '🐛 ' + _('Debug Options'))
		]);

		// Debug HTTP field
		debugSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Debug HTTP')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('label', {}, [
					debugHttpCheckbox = E('input', {
						'type': 'checkbox',
						'checked': config.debug_http === '1' ? 'checked' : null
					}),
					' ' + _('Enable HTTP debug logging')
				]),
				E('div', { 'class': 'cbi-value-description' },
					_('Log detailed HTTP communication for troubleshooting'))
			])
		]));

		// Debug APDU field
		debugSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Debug APDU')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('label', {}, [
					debugApduCheckbox = E('input', {
						'type': 'checkbox',
						'checked': config.debug_apdu === '1' ? 'checked' : null
					}),
					' ' + _('Enable APDU debug logging')
				]),
				E('div', { 'class': 'cbi-value-description' },
					_('Log detailed APDU commands for troubleshooting'))
			])
		]));

		// Log Level field
		var logLevelOptions = [
			{ value: 'debug', label: _('Debug') },
			{ value: 'info', label: _('Info') },
			{ value: 'warn', label: _('Warning') },
			{ value: 'error', label: _('Error') }
		].map(function(level) {
			return E('option', {
				'value': level.value,
				'selected': level.value === config.log_level ? 'selected' : null
			}, level.label);
		});

		debugSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Log Level')),
			E('div', { 'class': 'cbi-value-field' }, [
				logLevelSelect = E('select', { 'class': 'cbi-input-select' }, logLevelOptions),
				E('div', { 'class': 'cbi-value-description' },
					_('Set the verbosity level for lpac logging'))
			])
		]));

		container.appendChild(debugSection);

		// Advanced Settings section
		var advancedSettingsSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '🔧 ' + _('Advanced Settings'))
		]);

		// Timeout field
		advancedSettingsSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Timeout')),
			E('div', { 'class': 'cbi-value-field' }, [
				timeoutInput = E('input', {
					'type': 'number',
					'class': 'cbi-input-text',
					'value': config.timeout || '120',
					'min': '30',
					'max': '600'
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('Operation timeout in seconds (default: 120)'))
			])
		]));

		// Download Cooldown field
		advancedSettingsSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Download Cooldown')),
			E('div', { 'class': 'cbi-value-field' }, [
				downloadCooldownInput = E('input', {
					'type': 'number',
					'class': 'cbi-input-text',
					'value': config.download_cooldown || '60',
					'min': '0',
					'max': '300'
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('Cooldown period in seconds between profile downloads (default: 60)'))
			])
		]));

		// Auto Manage WWAN field
		advancedSettingsSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Auto Manage WWAN')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('label', {}, [
					autoManageWwanCheckbox = E('input', {
						'type': 'checkbox',
						'checked': config.auto_manage_wwan === '1' ? 'checked' : null
					}),
					' ' + _('Automatically stop/restart WWAN interface during eSIM operations')
				]),
				E('div', { 'class': 'cbi-value-description' },
					_('Prevents QMI device lock conflicts by stopping the network interface temporarily'))
			])
		]));

		// WWAN Interface field
		advancedSettingsSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('WWAN Interface')),
			E('div', { 'class': 'cbi-value-field' }, [
				wwanInterfaceInput = E('input', {
					'type': 'text',
					'class': 'cbi-input-text',
					'value': config.wwan_interface || 'wwan',
					'placeholder': 'wwan'
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('Network interface name to manage (e.g., wwan, wwan0, usb0)'))
			])
		]));

		// Auto SIM Power Cycle field
		advancedSettingsSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Auto SIM Power Cycle')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('label', {}, [
					autoSimPowerCycleCheckbox = E('input', {
						'type': 'checkbox',
						'checked': config.auto_sim_power_cycle === '1' ? 'checked' : null
					}),
					' ' + _('Automatically power cycle SIM after profile operations')
				]),
				E('div', { 'class': 'cbi-value-description' },
					_('Helps modem recognize newly activated/downloaded eSIM profiles (QMI only)'))
			])
		]));

		container.appendChild(advancedSettingsSection);

		// Save button section
		var saveSection = E('div', { 'class': 'cbi-section' }, [
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, ' '),
				E('div', { 'class': 'cbi-value-field' }, [
					E('button', {
						'class': 'btn cbi-button-action',
						'click': saveConfig
					}, _('Save Settings'))
				])
			])
		]);

		container.appendChild(saveSection);

		// Advanced Operations section
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
			E('h3', {}, '❓ ' + _('Configuration Help'))
		]);

		// Basic Configuration help
		helpSection.appendChild(E('div', { 'style': 'margin-bottom: 15px' }, [
			E('h4', {}, _('Basic Configuration')),
			E('p', {}, E('strong', {}, _('APDU Driver:'))),
			E('p', {}, _('Controls how lpac communicates with the eUICC chip. Options:')),
			E('ul', {}, [
				E('li', {}, [E('strong', {}, 'auto: '), _('Automatically detect the best driver')]),
				E('li', {}, [E('strong', {}, 'stdio: '), _('Standard input/output interface')]),
				E('li', {}, [E('strong', {}, 'at: '), _('AT command interface for modems')]),
				E('li', {}, [E('strong', {}, 'qmi_qrtr: '), _('Qualcomm MSM Interface')])
			]),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('HTTP Driver:'))),
			E('p', {}, _('Handles network communication with SM-DP+ servers for profile downloads and management. curl is recommended.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Default SM-DP+ Server:'))),
			E('p', {}, _('Optional default SM-DP+ server address for automatic profile discovery.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Auto Notification:'))),
			E('p', {}, _('When enabled, automatically process pending notifications from SM-DP+ servers.'))
		]));

		// Hardware Settings help
		helpSection.appendChild(E('div', { 'style': 'margin-bottom: 15px' }, [
			E('h4', {}, _('Hardware-Specific Settings')),
			E('p', {}, E('strong', {}, _('QMI Slot:'))),
			E('p', {}, _('For Qualcomm modems, specifies which SIM slot to use (1 or 2).')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('PCSC Reader:'))),
			E('p', {}, _('Specify a PC/SC smart card reader name. Leave empty to auto-detect the first available reader.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Custom AID:'))),
			E('p', {}, _('Application Identifier for the eUICC. Only change if you know your eUICC uses a non-standard AID.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('ES10X MSS:'))),
			E('p', {}, _('Maximum Segment Size for ES10 commands. Default is 60. Adjust if experiencing communication errors.'))
		]));

		// Debug Options help
		helpSection.appendChild(E('div', { 'style': 'margin-bottom: 15px' }, [
			E('h4', {}, _('Debug Options')),
			E('p', {}, E('strong', {}, _('Debug HTTP:'))),
			E('p', {}, _('Enable detailed HTTP logging for troubleshooting network communication issues.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Debug APDU:'))),
			E('p', {}, _('Enable detailed APDU command logging for troubleshooting chip communication issues.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Log Level:'))),
			E('p', {}, _('Set overall logging verbosity. Debug shows all messages, Error only shows critical issues.'))
		]));

		// Advanced Settings help
		helpSection.appendChild(E('div', { 'style': 'margin-bottom: 15px' }, [
			E('h4', {}, _('Advanced Settings')),
			E('p', {}, E('strong', {}, _('Timeout:'))),
			E('p', {}, _('Maximum time in seconds to wait for operations to complete. Increase for slow connections.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Download Cooldown:'))),
			E('p', {}, _('Wait time in seconds between consecutive profile downloads to prevent server rate limiting.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Auto Manage WWAN:'))),
			E('p', {}, _('Automatically stops and restarts the WWAN network interface during eSIM operations to prevent QMI device lock conflicts. When enabled, lpac can access the modem even when network interface is configured.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('WWAN Interface:'))),
			E('p', {}, _('Specifies which network interface to manage (e.g., wwan, wwan0, usb0). Different systems may use different interface names for cellular modems.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Auto SIM Power Cycle:'))),
			E('p', {}, _('Automatically power cycles the SIM card after profile operations. This helps the modem recognize newly activated, downloaded, or disabled eSIM profiles. Only works with QMI mode.'))
		]));

		// Advanced Operations help
		helpSection.appendChild(E('div', {}, [
			E('h4', {}, _('Advanced Operations')),
			E('p', {}, E('strong', {}, _('Profile Discovery:'))),
			E('p', {}, _('Search the SM-DS server for available eSIM profiles associated with your eUICC.')),
			E('p', { 'style': 'margin-top: 10px' }, E('strong', {}, _('Factory Reset:'))),
			E('p', {}, _('Permanently erases all eSIM profiles and returns the eUICC to factory state. Use only if absolutely necessary.'))
		]));

		container.appendChild(helpSection);

		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
