class App2appController < ApplicationController

	def start

	end

	def transfer

		#stores source and destination credentials for passing to other methods
		applicationcredentials = {
			src_appname: params[:src_appname],
			src_apikey: params[:src_apikey],
			dest_appname: params[:dest_appname],
			dest_apikey: params[:dest_apikey]
		}

		#transfers contacts if checkbox is checked
		transfer_contacts(applicationcredentials) unless params[:contacts][:checkbox] == 'false'

	end





	#adds contacts from source app to destination app
	#does not move custom fields or custom field data

	def transfer_contacts(appdata)

		#SOURCE APP
		#---------------------------------------

		#initialize source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#get all contacts from the source app
		all_contacts = get_table('Contact')

		#get list of opted out emails
		email_status_table = get_table('EmailAddStatus')
		opted_out_emails = []
		email_status_table.each do |email|
			opted_out_emails << email['Email'] if OPT_OUT_STATUSES.include? email['Type']
		end

		#get list of Lead Sources and Categories from source app
		source_app_lead_source_categories = get_table('LeadSourceCategory')
		source_app_lead_sources = get_table('LeadSource')

		#get list of users for comparing username to source app
		source_app_users = get_table('User')

		#gets lists of app settings for comparing to dest app
		source_types = Infusionsoft.data_get_app_setting('Contact','optiontypes').split(',')
		source_titles = Infusionsoft.data_get_app_setting('Contact','optiontitles').split(',')
		source_suffixes = Infusionsoft.data_get_app_setting('Contact','optionsuffixes').split(',')
		source_phonetypes = Infusionsoft.data_get_app_setting('Contact','optionphonetypes').split(',')
		source_faxtypes = Infusionsoft.data_get_app_setting('Contact','optionfaxtypes').split(',')


		#DESTINATION APP
		#--------------------------------------

		#INITIALIZATION
		#______________
		#initialize destination app
		initialize_infusionsoft(appdata[:dest_appname], appdata[:dest_apikey])

		#LEAD SOURCE
		#___________
		#creates Lead Sources and Categories if they don't exist
		#Adds all category names and lead source names to arrays to compare
		dest_app_lead_source_categories = []
		Infusionsoft.data_query('LeadSourceCategory',1000,0,{},['Name']).each do |cat|
			dest_app_lead_source_categories << cat['Name']
		end
		dest_app_lead_sources = []
		Infusionsoft.data_query('LeadSource',1000,0,{},['Name']).each do |src|
			dest_app_lead_sources << src['Name']
		end

		#adds lead source categories to dest app, and sets the ID of the source app lead source category equal to the category created
		#only adds lead source category if it doesn't already exist in dest app
		category_relationship = {}
		source_app_lead_source_categories.each do |cat|
			cat_src_id = cat['Id']
			cat['Id'] = Infusionsoft.data_add('LeadSourceCategory',cat) unless dest_app_lead_source_categories.include? cat['Name']
			category_relationship[cat_src_id] = cat['Id']
		end

		lead_source_relationship = {}
		source_app_lead_sources.each do |src|
			src_id = src['Id']
			src['LeadSourceCategoryId'] = category_relationship[src['LeadSourceCategoryId']] unless src['LeadSourceCategoryId'] == 0
			src['Id'] = Infusionsoft.data_add('LeadSource',src) unless dest_app_lead_sources.include? src['Name']
			lead_source_relationship[src_id] = src['Id']
		end

		#FKID CUSTOM FIELDS
		#__________________
		#creates Source App Contact and Company ID custom fields if they don't exist
		source_app_contact_id = create_custom_field('Source App Contact ID')
		source_app_company_id = create_custom_field('Source App Company ID')

		#switches the 'Id' key to be 'Source App Contact ID'
		#switches the 'CompanyID' key to be 'Source App Company ID'
		#also deletes the "AccountId" column, because that stores the ID of the attached company (which doesn't exist yet)
		rename_mapping = {"Id" => source_app_contact_id, "CompanyID" => source_app_company_id}
		all_contacts.each_with_index do |item, pos|
			all_contacts[pos].keys.each { |k| all_contacts[pos][ rename_mapping[k] ] = all_contacts[pos].delete(k).to_s if rename_mapping[k] }
			all_contacts[pos].delete('AccountId')
		end

		#USERS
		#_____
		#Matches up users based on their 'GlobalUserId' which is the Infusionsoft ID
		users_relationship = {0=>0}
		dest_app_users = get_table('User')
		source_app_users.each do |src_user|
			dest_app_users.each do |dest_user|
				users_relationship[src_user['Id']] = dest_user['Id'] if src_user['GlobalUserId'] == dest_user['GlobalUserId']
			end
		end

		#APP SETTINGS
		#____________
		#get all destination app settings
		dest_types = Infusionsoft.data_get_app_setting('Contact','optiontypes').split(',')
		dest_titles = Infusionsoft.data_get_app_setting('Contact','optiontitles').split(',')
		dest_suffixes = Infusionsoft.data_get_app_setting('Contact','optionsuffixes').split(',')
		dest_phonetypes = Infusionsoft.data_get_app_setting('Contact','optionphonetypes').split(',')
		dest_faxtypes = Infusionsoft.data_get_app_setting('Contact','optionfaxtypes').split(',')

		#create empty arrays to store missing settings
		@types = []
		@titles = []
		@suffixes = []
		@phonetypes = []
		@faxtypes = []

		#compare to source app, and remove items that exist in source app
		#resulting items will be arrays of settings that don't exist in the destination app
		source_types.each { |type| @types << type unless dest_types.include? type }
		source_titles.each { |title| @titles << title unless dest_titles.include? title }
		source_suffixes.each { |suffix| @suffixes << suffix unless dest_suffixes.include? suffix }
		source_phonetypes.each { |phonetype| @phonetypes << phonetype unless dest_phonetypes.include? phonetype }
		source_faxtypes.each { |faxtype| @faxtypes << faxtype unless dest_faxtypes.include? faxtype }

		#ADD CONTACTS
		#____________
		#adds each contact in the list of contacts to destination app
		#swaps lead source IDs before import to dest app lead source ID
		#swaps user ID to destination app user ID based on users_relationship matching
		#all_contacts.each do |contact|
			#contact['LeadSourceId'] = lead_source_relationship[contact['LeadSourceId']] unless contact['LeadSourceId'] == 0
			#users_relationship[contact['OwnerID']] == nil ? contact['OwnerID'] = 0 : contact['OwnerID'] = users_relationship[contact['OwnerID']]
			#Infusionsoft.contact_add(contact)
		#end

		#opt out all emails that were opted out in the source app
		#opted_out_emails.each do |email|
			#Infusionsoft.email_optout(email, 'Source App Opt Out')
		#end

	end
end
