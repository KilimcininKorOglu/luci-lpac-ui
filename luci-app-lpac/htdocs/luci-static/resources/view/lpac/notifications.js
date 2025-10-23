// notifications.js - Notifications management view for luci-app-lpac
// Copyright (C) 2025
// Licensed under GPL-3.0

'use strict';
'require view';
'require request';
'require ui';

return view.extend({
	load: function() {
		return Promise.all([
			request.get('/cgi-bin/luci/admin/network/lpac/api/list_notifications'),
			request.get('/cgi-bin/luci/admin/network/lpac/api/check_lpac')
		]);
	},

	render: function(data) {
		// Parse JSON responses from responseText
		var notificationsResponse = data[0] ? JSON.parse(data[0].responseText || '{}') : {};
		var lpacCheckResponse = data[1] ? JSON.parse(data[1].responseText || '{}') : {};

		var notifications = (notificationsResponse && notificationsResponse.data &&
			notificationsResponse.data.notifications) ? notificationsResponse.data.notifications : [];
		var lpacAvailable = (lpacCheckResponse && lpacCheckResponse.success && lpacCheckResponse.data &&
			lpacCheckResponse.data.installed) ? true : false;

		var container = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('Notification Management')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Manage eUICC notifications from SM-DP+ servers'))
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
		if (!notificationsResponse || !notificationsResponse.success) {
			container.appendChild(E('div', { 'class': 'alert-message error' }, [
				E('h4', {}, _('Failed to Load Notifications')),
				E('p', {}, notificationsResponse ? notificationsResponse.message : _('Unknown error occurred'))
			]));
			return container;
		}

		// Helper: Refresh page
		var refreshPage = function() {
			window.location.reload();
		};

		// Helper: Process notification
		var processNotification = function(seqNumber) {
			ui.showModal(_('Process Notification'), [
				E('p', {}, _('Process this notification from the SM-DP+ server?')),
				E('p', {}, [
					E('strong', {}, _('Sequence Number: ')),
					seqNumber
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', {}, [
						E('input', {
							'type': 'checkbox',
							'id': 'remove-after-process',
							'checked': 'checked'
						}),
						' ' + _('Remove notification after processing')
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
							var removeAfter = document.getElementById('remove-after-process').checked;

							ui.showModal(_('Processing Notification'), [
								E('p', { 'class': 'spinning' }, _('Please wait...'))
							]);

							request.post('/cgi-bin/luci/admin/network/lpac/api/process_notification', {
								seq_number: seqNumber,
								remove: removeAfter
							}).then(function(xhr) {
								ui.hideModal();
								var response = xhr ? JSON.parse(xhr.responseText || '{}') : {};
								if (response && response.success) {
									ui.addNotification(null,
										E('p', {}, _('Notification processed successfully')), 'info');
									refreshPage();
								} else {
									ui.addNotification(null,
										E('p', {}, _('Failed to process notification: ') +
											(response ? response.message : _('Unknown error'))), 'error');
								}
							}).catch(function(err) {
								ui.hideModal();
								ui.addNotification(null,
									E('p', {}, _('Error processing notification: ') + err.message), 'error');
							});
						}
					}, _('Process'))
				])
			]);
		};

		// Helper: Remove notification
		var removeNotification = function(seqNumber) {
			ui.showModal(_('Remove Notification'), [
				E('p', {}, _('Remove this notification without processing?')),
				E('p', {}, [
					E('strong', {}, _('Sequence Number: ')),
					seqNumber
				]),
				E('div', { 'class': 'alert-message warning' }, [
					E('p', {}, _('The notification will be permanently removed from the eUICC.'))
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
							ui.showModal(_('Removing Notification'), [
								E('p', { 'class': 'spinning' }, _('Please wait...'))
							]);

							request.post('/cgi-bin/luci/admin/network/lpac/api/remove_notification', {
								seq_number: seqNumber
							}).then(function(xhr) {
								ui.hideModal();
								var response = xhr ? JSON.parse(xhr.responseText || '{}') : {};
								if (response && response.success) {
									ui.addNotification(null,
										E('p', {}, _('Notification removed successfully')), 'info');
									refreshPage();
								} else {
									ui.addNotification(null,
										E('p', {}, _('Failed to remove notification: ') +
											(response ? response.message : _('Unknown error'))), 'error');
								}
							}).catch(function(err) {
								ui.hideModal();
								ui.addNotification(null,
									E('p', {}, _('Error removing notification: ') + err.message), 'error');
							});
						}
					}, _('Remove'))
				])
			]);
		};

		// Helper: Process all notifications
		var processAllNotifications = function() {
			ui.showModal(_('Process All Notifications'), [
				E('p', {}, _('Process all pending notifications from SM-DP+ servers?')),
				E('p', {}, [
					E('strong', {}, _('Total Notifications: ')),
					notifications.length
				]),
				E('div', { 'class': 'alert-message warning' }, [
					E('p', {}, _('This operation may take several minutes if there are many notifications.'))
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
							ui.showModal(_('Processing All Notifications'), [
								E('p', { 'class': 'spinning' }, _('Please wait, this may take several minutes...')),
								E('p', {}, _('Processing ') + notifications.length + _(' notification(s)'))
							]);

							request.post('/cgi-bin/luci/admin/network/lpac/api/process_all_notifications', {})
								.then(function(response) {
									ui.hideModal();
									if (response && response.success) {
										ui.addNotification(null,
											E('p', {}, _('All notifications processed successfully')), 'info');
										refreshPage();
									} else {
										ui.addNotification(null,
											E('p', {}, _('Failed to process all notifications: ') +
												(response ? response.message : _('Unknown error'))), 'error');
									}
								})
								.catch(function(err) {
									ui.hideModal();
									ui.addNotification(null,
										E('p', {}, _('Error processing notifications: ') + err.message), 'error');
								});
						}
					}, _('Process All'))
				])
			]);
		};

		// Helper: Remove all notifications
		var removeAllNotifications = function() {
			ui.showModal(_('Remove All Notifications'), [
				E('p', {}, _('Remove all pending notifications without processing?')),
				E('p', {}, [
					E('strong', {}, _('Total Notifications: ')),
					notifications.length
				]),
				E('div', { 'class': 'alert-message warning' }, [
					E('p', {}, _('All notifications will be permanently removed from the eUICC.'))
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
							ui.showModal(_('Removing All Notifications'), [
								E('p', { 'class': 'spinning' }, _('Please wait...'))
							]);

							request.post('/cgi-bin/luci/admin/network/lpac/api/remove_all_notifications', {})
								.then(function(response) {
									ui.hideModal();
									if (response && response.success) {
										ui.addNotification(null,
											E('p', {}, _('All notifications removed successfully')), 'info');
										refreshPage();
									} else {
										ui.addNotification(null,
											E('p', {}, _('Failed to remove all notifications: ') +
												(response ? response.message : _('Unknown error'))), 'error');
									}
								})
								.catch(function(err) {
									ui.hideModal();
									ui.addNotification(null,
										E('p', {}, _('Error removing notifications: ') + err.message), 'error');
								});
						}
					}, _('Remove All'))
				])
			]);
		};

		// Notifications section
		var notificationsSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '🔔 ' + _('Pending Notifications') + ' (' + notifications.length + ')')
		]);

		if (notifications.length === 0) {
			notificationsSection.appendChild(E('div', { 'class': 'alert-message success' }, [
				E('p', {}, '✓ ' + _('No pending notifications')),
				E('p', {}, _('Your eUICC has no pending notifications from SM-DP+ servers.'))
			]));
		} else {
			// Bulk action buttons
			notificationsSection.appendChild(E('div', { 'style': 'margin-bottom: 15px' }, [
				E('button', {
					'class': 'btn cbi-button-action',
					'click': processAllNotifications
				}, _('Process All')),
				' ',
				E('button', {
					'class': 'btn cbi-button-negative',
					'click': removeAllNotifications
				}, _('Remove All'))
			]));

			// Create notifications table
			var tableRows = notifications.map(function(notification) {
				var seqNumber = notification.seqNumber || notification.seq_number || _('Unknown');
				var operation = notification.notificationOperation || notification.operation || _('Unknown');
				var address = notification.notificationAddress || notification.address || _('N/A');

				// Action buttons
				var actionButtons = E('div', { 'style': 'display: flex; gap: 5px; flex-wrap: wrap' });

				actionButtons.appendChild(E('button', {
					'class': 'btn cbi-button-action',
					'click': function() {
						processNotification(seqNumber);
					}
				}, _('Process')));

				actionButtons.appendChild(E('button', {
					'class': 'btn cbi-button-negative',
					'click': function() {
						removeNotification(seqNumber);
					}
				}, _('Remove')));

				return E('tr', {}, [
					E('td', { 'style': 'width: 15%; text-align: center' },
						E('code', {}, String(seqNumber))),
					E('td', { 'style': 'width: 25%' }, operation),
					E('td', { 'style': 'width: 40%' },
						E('code', { 'style': 'font-size: 11px' }, address)),
					E('td', { 'style': 'width: 20%' }, actionButtons)
				]);
			});

			var table = E('table', { 'class': 'table' }, [
				E('thead', {}, [
					E('tr', {}, [
						E('th', { 'style': 'text-align: center' }, _('Seq #')),
						E('th', {}, _('Operation')),
						E('th', {}, _('Address')),
						E('th', {}, _('Actions'))
					])
				]),
				E('tbody', {}, tableRows)
			]);

			notificationsSection.appendChild(table);
		}

		// Refresh button
		notificationsSection.appendChild(E('div', { 'style': 'margin-top: 15px' }, [
			E('button', {
				'class': 'btn cbi-button',
				'click': refreshPage
			}, _('Refresh'))
		]));

		container.appendChild(notificationsSection);

		// Help section
		var helpSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, '❓ ' + _('About Notifications')),
			E('p', {}, _('Notifications are messages from SM-DP+ servers regarding profile operations:')),
			E('ul', {}, [
				E('li', {}, E('strong', {}, _('Install: ')) +
					_('A new profile is available for download')),
				E('li', {}, E('strong', {}, _('Enable: ')) +
					_('Request to enable a profile')),
				E('li', {}, E('strong', {}, _('Disable: ')) +
					_('Request to disable a profile')),
				E('li', {}, E('strong', {}, _('Delete: ')) +
					_('Request to delete a profile'))
			]),
			E('p', {}, _('Actions:')),
			E('ul', {}, [
				E('li', {}, E('strong', {}, _('Process: ')) +
					_('Execute the requested operation and optionally remove the notification')),
				E('li', {}, E('strong', {}, _('Remove: ')) +
					_('Delete the notification without processing'))
			]),
			E('p', {}, _('Processing notifications regularly helps keep your eUICC synchronized with SM-DP+ servers.'))
		]);

		container.appendChild(helpSection);

		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
