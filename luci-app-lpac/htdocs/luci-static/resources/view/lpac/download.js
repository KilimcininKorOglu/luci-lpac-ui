// download.js - Profile download view for luci-app-lpac
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
			request.get('/cgi-bin/luci/admin/network/lpac/api/check_lpac')
		]);
	},

	render: function(data) {
		var lpacCheckResponse = data[0];
		var lpacAvailable = (lpacCheckResponse && lpacCheckResponse.data && lpacCheckResponse.data.installed) ? true : false;

		var container = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('Download eSIM Profile')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Download and install a new eSIM profile from your mobile operator'))
		]);

		// lpac availability check
		if (!lpacAvailable) {
			container.appendChild(E('div', { 'class': 'alert-message warning' }, [
				E('h4', {}, _('lpac Not Installed')),
				E('p', {}, _('The lpac binary is not installed or not executable. Please install lpac package first.'))
			]));
			return container;
		}

		// Download method selection
		var methodRadio;
		var activationCodeInput;
		var smdpInput;
		var matchingIdInput;
		var confirmationCodeInput;
		var imeiInput;
		var manualFields;

		var updateFormVisibility = function() {
			var method = methodRadio.querySelector('input:checked').value;
			if (method === 'activation_code') {
				activationCodeInput.parentElement.parentElement.style.display = '';
				manualFields.style.display = 'none';
			} else {
				activationCodeInput.parentElement.parentElement.style.display = 'none';
				manualFields.style.display = '';
			}
		};

		// Download function
		var downloadProfile = function() {
			var method = methodRadio.querySelector('input:checked').value;
			var options = {};

			if (method === 'activation_code') {
				var activationCode = activationCodeInput.value.trim();
				if (!activationCode) {
					ui.addNotification(null,
						E('p', {}, _('Activation code is required')), 'error');
					return;
				}
				options.activation_code = activationCode;
			} else {
				var smdp = smdpInput.value.trim();
				var matchingId = matchingIdInput.value.trim();

				if (!smdp) {
					ui.addNotification(null,
						E('p', {}, _('SM-DP+ address is required')), 'error');
					return;
				}

				options.smdp = smdp;
				if (matchingId) options.matching_id = matchingId;
				if (confirmationCodeInput.value.trim()) {
					options.confirmation_code = confirmationCodeInput.value.trim();
				}
				if (imeiInput.value.trim()) {
					options.imei = imeiInput.value.trim();
				}
			}

			// Confirmation dialog
			ui.showModal(_('Download Profile'), [
				E('p', {}, _('Are you sure you want to download this profile?')),
				method === 'activation_code' ?
					E('p', {}, [
						E('strong', {}, _('Activation Code: ')),
						E('br'),
						E('code', { 'style': 'font-size: 11px; word-break: break-all' },
							options.activation_code)
					]) :
					E('div', {}, [
						E('p', {}, [
							E('strong', {}, _('SM-DP+ Address: ')),
							E('code', {}, options.smdp)
						]),
						options.matching_id ? E('p', {}, [
							E('strong', {}, _('Matching ID: ')),
							E('code', {}, options.matching_id)
						]) : null
					]),
				E('div', { 'class': 'alert-message warning' }, [
					E('p', {}, _('This operation may take several minutes. Please do not close this page or disconnect the eUICC during download.'))
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
							ui.showModal(_('Downloading Profile'), [
								E('p', { 'class': 'spinning' }, _('Please wait, this may take several minutes...')),
								E('p', {}, _('Do not close this page or disconnect the eUICC.'))
							]);

							request.post('/cgi-bin/luci/admin/network/lpac/api/download_profile', options)
								.then(function(response) {
									ui.hideModal();
									if (response && response.success) {
										ui.showModal(_('Success'), [
											E('div', { 'class': 'alert-message success' }, [
												E('h4', {}, '✓ ' + _('Profile Downloaded Successfully')),
												E('p', {}, _('The eSIM profile has been downloaded and installed on your eUICC.'))
											]),
											response.data && response.data.iccid ?
												E('p', {}, [
													E('strong', {}, _('ICCID: ')),
													E('code', {}, response.data.iccid)
												]) : null,
											E('div', { 'class': 'right' }, [
												E('button', {
													'class': 'btn cbi-button-action',
													'click': function() {
														window.location.href = L.url('admin', 'network', 'lpac', 'profiles');
													}
												}, _('View Profiles')),
												' ',
												E('button', {
													'class': 'btn',
													'click': function() {
														ui.hideModal();
														// Clear form
														activationCodeInput.value = '';
														smdpInput.value = '';
														matchingIdInput.value = '';
														confirmationCodeInput.value = '';
														imeiInput.value = '';
													}
												}, _('Download Another'))
											])
										]);
									} else {
										ui.addNotification(null,
											E('p', {}, _('Failed to download profile: ') +
												(response ? response.message : _('Unknown error'))), 'error');
									}
								})
								.catch(function(err) {
									ui.hideModal();
									ui.addNotification(null,
										E('p', {}, _('Error downloading profile: ') + err.message), 'error');
								});
						}
					}, _('Download'))
				])
			]);
		};

		// Form section
		var formSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '📥 ' + _('Download Method'))
		]);

		// Method selection
		methodRadio = E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Method')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('div', {}, [
					E('label', { 'style': 'display: inline-block; margin-right: 20px' }, [
						E('input', {
							'type': 'radio',
							'name': 'download_method',
							'value': 'activation_code',
							'checked': 'checked',
							'change': updateFormVisibility
						}),
						' ' + _('Activation Code (QR Code)')
					]),
					E('label', { 'style': 'display: inline-block' }, [
						E('input', {
							'type': 'radio',
							'name': 'download_method',
							'value': 'manual',
							'change': updateFormVisibility
						}),
						' ' + _('Manual Entry')
					])
				])
			])
		]);

		formSection.appendChild(methodRadio);

		// Activation code field
		formSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Activation Code')),
			E('div', { 'class': 'cbi-value-field' }, [
				activationCodeInput = E('input', {
					'type': 'text',
					'class': 'cbi-input-text',
					'placeholder': 'LPA:1$smdp.example.com$MATCHING_ID',
					'style': 'font-family: monospace'
				}),
				E('div', { 'class': 'cbi-value-description' },
					_('Scan the QR code from your mobile operator or paste the activation code string'))
			])
		]));

		// Manual entry fields (initially hidden)
		manualFields = E('div', { 'style': 'display: none' }, [
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, _('SM-DP+ Address') + ' *'),
				E('div', { 'class': 'cbi-value-field' }, [
					smdpInput = E('input', {
						'type': 'text',
						'class': 'cbi-input-text',
						'placeholder': 'smdp.example.com'
					}),
					E('div', { 'class': 'cbi-value-description' },
						_('The SM-DP+ server address provided by your mobile operator'))
				])
			]),
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, _('Matching ID')),
				E('div', { 'class': 'cbi-value-field' }, [
					matchingIdInput = E('input', {
						'type': 'text',
						'class': 'cbi-input-text',
						'placeholder': 'MATCHING_ID_STRING'
					}),
					E('div', { 'class': 'cbi-value-description' },
						_('Optional matching ID for profile selection'))
				])
			]),
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, _('Confirmation Code')),
				E('div', { 'class': 'cbi-value-field' }, [
					confirmationCodeInput = E('input', {
						'type': 'text',
						'class': 'cbi-input-text',
						'placeholder': '1234-5678'
					}),
					E('div', { 'class': 'cbi-value-description' },
						_('Optional confirmation code if required by the operator'))
				])
			]),
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, _('IMEI')),
				E('div', { 'class': 'cbi-value-field' }, [
					imeiInput = E('input', {
						'type': 'text',
						'class': 'cbi-input-text',
						'placeholder': '123456789012345',
						'maxlength': '15',
						'pattern': '[0-9]*'
					}),
					E('div', { 'class': 'cbi-value-description' },
						_('Optional IMEI number (15 digits) if required by the operator'))
				])
			])
		]);

		formSection.appendChild(manualFields);

		// Download button
		formSection.appendChild(E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, ' '),
			E('div', { 'class': 'cbi-value-field' }, [
				E('button', {
					'class': 'btn cbi-button-action',
					'click': downloadProfile
				}, _('Download Profile'))
			])
		]));

		container.appendChild(formSection);

		// Help section
		var helpSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '❓ ' + _('Help')),
			E('p', {}, _('To download an eSIM profile, you need either:')),
			E('ul', {}, [
				E('li', {}, _('An activation code (QR code) provided by your mobile operator')),
				E('li', {}, _('Or the SM-DP+ server address and optional matching ID'))
			]),
			E('p', {}, _('The download process may take several minutes. Make sure:')),
			E('ul', {}, [
				E('li', {}, _('The eUICC chip is properly connected')),
				E('li', {}, _('You have internet connectivity')),
				E('li', {}, _('There is enough free memory on the eUICC'))
			]),
			E('p', {}, [
				_('After downloading, you can manage your profiles on the '),
				E('a', { 'href': L.url('admin', 'network', 'lpac', 'profiles') }, _('Profiles')),
				_(' page.')
			])
		]);

		container.appendChild(helpSection);

		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
