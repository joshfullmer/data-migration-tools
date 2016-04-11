class App2appController < ApplicationController

	@@source_app_contact_id = "_SourceAppContactID0"
	@@source_app_company_id = "_SourceAppCompanyID"
	@@source_app_account_id = "_SourceAppCompanyID"

	@@subscription_relationship = {}

	$types = ["none"]
	$titles = ["none"]
	$suffixes = ["none"]
	$phonetypes = ["none"]
	$faxtypes = ["none"]

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
		transfer_contacts(applicationcredentials,params[:customfields][:checkbox] == 'true') unless params[:contacts][:checkbox] == 'false'
		transfer_companies(applicationcredentials) unless params[:companies][:checkbox] == 'false'
		transfer_tags(applicationcredentials,params[:companies][:checkbox] == 'true') unless params[:tags][:checkbox] == 'false'
		transfer_contact_actions(applicationcredentials,params[:notes][:checkbox] == 'true',params[:tasks][:checkbox] == 'true',params[:appointments][:checkbox] == 'true') if params[:notes][:checkbox] == 'true' || params[:tasks][:checkbox] == 'true' || params[:appointments][:checkbox] == 'true'
		transfer_products(applicationcredentials) unless params[:products][:checkbox] == 'false'
		transfer_opportunities(applicationcredentials) unless params[:opportunities][:checkbox] == 'false'
		transfer_attachments(applicationcredentials) unless params[:attachments][:checkbox] == 'false'
		transfer_orders(applicationcredentials) unless params[:orders][:checkbox] == 'false'
	end





	#adds contacts from source app to destination app
	#does not move custom fields or custom field data

	def transfer_contacts(appdata,customfieldscheck)

		puts "Importing Contacts..."

		#SOURCE APP
		#---------------------------------------

		#initialize source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#get list of contact custom fields
		#then store the list of names in an array to add to fields for lookup
		source_app_custom_fields = get_table('DataFormField')
		contact_fields = []
		contact_fields = FIELDS['Contact'].map(&:clone)
		source_app_custom_fields.each do |customfield|
			contact_fields.push("_" + customfield['Name']) if customfield['FormId'] == -1
		end

		#get all contacts from the source app
		all_contacts = get_table('Contact',contact_fields)

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

		puts "=> Importing Lead Sources..."

		#creates Lead Sources and Categories if they don't exist
		#Adds all category names and lead source names to hashes to compare
		dest_app_lead_source_categories = {}
		get_table('LeadSourceCategory').each do |cat|
			dest_app_lead_source_categories[cat['Id']] = cat['Name']
		end
		dest_app_lead_sources = {}
		get_table('LeadSource').each do |src|
			dest_app_lead_sources[src['Id']] = src['Name']
		end

		#adds lead source categories to dest app, and sets the ID of the source app lead source category equal to the category created
		#only adds lead source category if it doesn't already exist in dest app
		category_relationship = {}
		source_app_lead_source_categories.each do |cat|
			category_relationship[cat['Id']] = dest_app_lead_source_categories.key(cat['Name']) == nil ? Infusionsoft.data_add('LeadSourceCategory',cat) : dest_app_lead_source_categories.key(cat['Name'])
		end

		lead_source_relationship = {0=>0}
		source_app_lead_sources.each do |src|
			src['LeadSourceCategoryId'] = category_relationship[src['LeadSourceCategoryId']] unless src['LeadSourceCategoryId'] == 0
			lead_source_relationship[src['Id']] = dest_app_lead_sources.key(src['Name']) == nil ? Infusionsoft.data_add('LeadSource',src) : dest_app_lead_sources.key(src['Name'])
		end

		#FKID AND CONTACT CUSTOM FIELDS
		#__________________

		puts "=> Importing Custom Fields..."

		#creates Source App Contact and Company ID custom fields if they don't exist
		@@source_app_contact_id = create_custom_field('Source App Contact ID')
		@@source_app_company_id = create_custom_field('Source App Company ID')

		#create contact custom fields if the custom fields check is true
		rename_mapping = {}
		if customfieldscheck
			source_app_custom_fields.each do |customfield|
				if customfield['FormId'] == -1
					rename_mapping['_' + customfield['Name']] = create_custom_field(customfield['Label'],0,'Contact',DATATYPES[DATATYPE_IDS[customfield['DataType']]]['dataType'])
					customfieldid = Infusionsoft.data_query('DataFormField',1000,0,{ Label: customfield['Label'] },['Id'])[0]['Id']
					Infusionsoft.data_update_custom_field(customfieldid,{ 'Values' => customfield['Values'] }) if DATATYPES[DATATYPE_IDS[customfield['DataType']]]['hasValues'] == 'yes'  && customfield['Values'] != nil
				end
			end
		end

		#switches the 'Id' key to be 'Source App Contact ID'
		#switches the 'CompanyID' key to be 'Source App Company ID'
		#also deletes the "AccountId" column, because that stores the ID of the attached company (which doesn't exist yet)
		rename_mapping['Id'] = @@source_app_contact_id
		rename_mapping['CompanyID'] = @@source_app_company_id
		all_contacts.each_with_index do |item, pos|
			all_contacts[pos].keys.each { |k| all_contacts[pos][ rename_mapping[k] ] = all_contacts[pos].delete(k).to_s if rename_mapping[k] }
			all_contacts[pos].delete('AccountId')
		end

		#USERS
		#_____
		#Matches up users based on their 'GlobalUserId' which is the Infusionsoft ID
		users_relationship = create_user_relationship(source_app_users,get_table('User'))

		#APP SETTINGS
		#____________
		#get all destination app settings
		dest_types = Infusionsoft.data_get_app_setting('Contact','optiontypes').split(',')
		dest_titles = Infusionsoft.data_get_app_setting('Contact','optiontitles').split(',')
		dest_suffixes = Infusionsoft.data_get_app_setting('Contact','optionsuffixes').split(',')
		dest_phonetypes = Infusionsoft.data_get_app_setting('Contact','optionphonetypes').split(',')
		dest_faxtypes = Infusionsoft.data_get_app_setting('Contact','optionfaxtypes').split(',')

		#create empty arrays to store missing settings
		$types = []
		$titles = []
		$suffixes = []
		$phonetypes = []
		$faxtypes = []

		#compare to source app, and remove items that exist in source app
		#resulting items will be arrays of settings that don't exist in the destination app
		source_types.each { |type| $types << type unless dest_types.include? type }
		source_titles.each { |title| $titles << title unless dest_titles.include? title }
		source_suffixes.each { |suffix| $suffixes << suffix unless dest_suffixes.include? suffix }
		source_phonetypes.each { |phonetype| $phonetypes << phonetype unless dest_phonetypes.include? phonetype }
		source_faxtypes.each { |faxtype| $faxtypes << faxtype unless dest_faxtypes.include? faxtype }

		#CREATE IMPORT TAG
		#_________________

		puts "=> Creating Import Tag..."

		import_tag_cat_id = Infusionsoft.data_add('ContactGroupCategory',{'CategoryName' => 'Application Transfer'})
		import_tag_id = Infusionsoft.data_add('ContactGroup',{'GroupCategoryId' => import_tag_cat_id, 'GroupName' => "Data from #{appdata[:src_appname]}"})

		#ADD CONTACTS
		#____________

		puts "=> Adding contacts..."

		#adds each contact in the list of contacts to destination app
		#swaps lead source IDs before import to dest app lead source ID
		#swaps user ID to destination app user ID based on users_relationship matching
		all_contacts.each do |contact|
			contact['LeadSourceId'] = lead_source_relationship[contact['LeadSourceId']]
			users_relationship[contact['OwnerID']] == nil ? contact['OwnerID'] = 0 : contact['OwnerID'] = users_relationship[contact['OwnerID']]
			contact_id = Infusionsoft.contact_add(contact) unless contact[@@source_app_contact_id] == contact[@@source_app_company_id]
			Infusionsoft.contact_add_to_group(contact_id, import_tag_id) unless contact_id.nil?
		end

		#opt out all emails that were opted out in the source app
		opted_out_emails.each do |email|
			Infusionsoft.email_optout(email, 'Source App Opt Out')
		end

		puts "Contacts Imported."

	end

	def transfer_companies(appdata)

		puts "Importing Companies..."

		#SOURCE APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#SOURCE APP DATA
		#_______________
		#Gets source app companies and company custom fields
		source_app_custom_fields = get_table('DataFormField')
		company_fields = []
		company_fields = FIELDS['Company'].map(&:clone)

		source_app_custom_fields.each do |customfield|
			company_fields << ("_" + customfield['Name']) if customfield['FormId'] == -6
		end

		#gets source companies with custom fields.
		source_companies = get_table('Company',company_fields)

		#gets source contacts with source companyID to match up
		source_contacts = get_table('Contact')

		#DESTINATION APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes destination app
		initialize_infusionsoft(appdata[:dest_appname], appdata[:dest_apikey])

		#CREATE COMPANY CUSTOM FIELDS
		#____________________
		#get tab id for first company custom field tab, then get header tab using that tab id
		custom_field_tab_id = Infusionsoft.data_query('DataFormTab',1000,0,{'FormId' => -6},['Id'])[0]['Id']
		custom_field_header_id = Infusionsoft.data_query('DataFormGroup',1000,0,{'TabId' => custom_field_tab_id},['Id'])[0]['Id']

		#create company custom fields if they don't exist, and store the rename mapping in a hash for use later
		rename_mapping = {}
		source_app_custom_fields.each do |customfield|
			if customfield['FormId'] == -6
				rename_mapping['_' + customfield['Name']] = create_custom_field(customfield['Label'],custom_field_header_id,'Company',DATATYPES[DATATYPE_IDS[customfield['DataType']]]['dataType'])
				customfieldid = Infusionsoft.data_query('DataFormField',1000,0,{ Label: customfield['Label'] },['Id'])[0]['Id']
				Infusionsoft.data_update_custom_field(customfieldid,{ 'Values' => customfield['Values'] }) if DATATYPES[DATATYPE_IDS[customfield['DataType']]]['hasValues'] == 'yes'  && customfield['Values'] != nil
			end
		end

		#RENAME COMPANY FIELDS TO MATCH CUSTOM FIELDS
		#____________________________________________
		@@source_app_account_id = create_custom_field('Source App Company ID',custom_field_header_id,'Company','Text')
		rename_mapping['Id'] = @@source_app_account_id
		source_companies.each_with_index do |item, pos|
			source_companies[pos].keys.each { |k| source_companies[pos][ rename_mapping[k] ] = source_companies[pos].delete(k).to_s if rename_mapping[k] }
		end

		#IMPORT COMPANIES
		#________________
		company_relationship = {}
		source_companies.each do |comp|
			company_relationship[comp['CompanyID']] = Infusionsoft.data_add('Company',comp)
		end

		#ASSIGN CONTACTS TO COMPANIES
		#____________________________
		contact_ids_relationship = {}
		get_table('Contact',[@@source_app_contact_id,'Id']).each do |cont|
			contact_ids_relationship[cont[@@source_app_contact_id].to_i] = cont['Id'] unless cont[@@source_app_contact_id] == nil
		end

		source_contacts.each do |cont|
			Infusionsoft.data_update('Contact',contact_ids_relationship[cont['Id']],{'AccountId' => company_relationship[cont['AccountId'].to_i]}) unless cont['AccountId'] == 0 || cont['AccountId'] == cont['Id']
		end

		puts "Companies Imported."

	end

	#creates tags in destination app
	#only creates tags that don't have an exact match, matching both name and category

	def transfer_tags(appdata,companytagcheck)

		puts "Importing Tags..."

		#SOURCE APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#SOURCE APP DATA
		#_______________
		#Gets source app tags and tag categories
		source_tag_categories = get_table('ContactGroupCategory')
		source_tags = get_table('ContactGroup')

		#gets tag assignments
		source_tag_assignments = get_table('ContactGroupAssign')


		#DESTINATION APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes destination app
		initialize_infusionsoft(appdata[:dest_appname], appdata[:dest_apikey])

		#DEST APP DATA
		#_____________
		#gets tags and tag categories that already exist in destination app
		dest_tag_categories = {}
		get_table('ContactGroupCategory').each do |cat|
			dest_tag_categories[cat['Id']] = cat['CategoryName']
		end

		dest_tags = {}
		get_table('ContactGroup').each do |tag|
			dest_tags[tag['Id']] = tag['GroupName']
		end

		dest_contacts = {}
		get_table('Contact',['Id',@@source_app_contact_id]).each do |contact|
			dest_contacts[contact[@@source_app_contact_id].to_i] = contact['Id']
		end

		dest_companies = {}
		get_table('Company',['Id',@@source_app_account_id]).each do |company|
			dest_companies[company[@@source_app_account_id].to_i] = company['Id']
		end

		#CREATE TAGS AND CATEGORIES
		#__________________________
		#Create Categories and tags if they don't already exist
		category_relationship = {}
		source_tag_categories.each do |cat|
			category_relationship[cat['Id']] = dest_tag_categories.key(cat['CategoryName']).nil? ? Infusionsoft.data_add('ContactGroupCategory',cat) : dest_tag_categories.key(cat['CategoryName'])
		end

		tag_relationship = {}
		source_tags.each do |tag|
			tag['GroupCategoryId'] = category_relationship[tag['GroupCategoryId']] unless tag['GroupCategoryId'] == 0
			tag_relationship[tag['Id']] = dest_tags.key(tag['GroupName']) == nil ? Infusionsoft.data_add('ContactGroup',tag) : dest_tags.key(tag['GroupName'])
		end

		#ADD TAGS TO CONTACTS & COMPANIES
		#________________________________
		#adds tags to contacts using the ContactGroupAssign table from the source app
		source_tag_assignments.each do |contact|
			contact['GroupId'] = tag_relationship[contact['GroupId']]
			dest_contacts[contact['ContactId']].nil? ? Infusionsoft.contact_add_to_group(dest_companies[contact['Contact.CompanyID']], contact['GroupId']) : Infusionsoft.contact_add_to_group(dest_contacts[contact['ContactId']], contact['GroupId'])
		end

		puts "Tags Imported."

	end

	def transfer_contact_actions(appdata,notescheck,taskscheck,appointmentscheck)

		puts "Importing Notes/Tasks/Appointments..."

		#SOURCE APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#SOURCE APP DATA
		#_______________
		#get contact action table and user id table
		source_contact_actions = get_table('ContactAction')
		source_app_users = get_table('User')

		#DESTINATION APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes destination app
		initialize_infusionsoft(appdata[:dest_appname], appdata[:dest_apikey])

		#DEST APP DATA
		#_____________
		#get contact and source ids
		#get user relationship - Hash where key is dest ID and value is source ID
		contact_ids = get_table('Contact',['Id',@@source_app_contact_id])
		contact_ids_relationship = {}
		contact_ids.each do |id|
			contact_ids_relationship[id[@@source_app_contact_id].to_i] = id['Id']
		end
		users_relationship = create_user_relationship(source_app_users,get_table('User'))

		#TRANSFER TASKS NOTES APPTS
		#__________________________
		#checks for the parameter if each type should be transferred
		transfer_check = {
			'Note' => notescheck,
			'Task' => taskscheck,
			'Appointment' => appointmentscheck
		}
		default_user_id = Infusionsoft.data_get_app_setting('Templates','defuserid')
		source_contact_actions.each do |action|
			action.except!('OpportunityId')
			action['ContactId'] = contact_ids_relationship[action['ContactId']].nil? == true ? default_user_id : contact_ids_relationship[action['ContactId']]
			action['UserID'] = users_relationship[action['UserID']].nil? == true ? 0 : users_relationship[action['UserID']]
			action['ActionDescription'].prepend("[Task] ") if action['ObjectType'] == 'Task' && action['ActionDescription'].nil? == false
			Infusionsoft.data_add('ContactAction',action) if transfer_check[action['ObjectType']]
		end

		puts "Notes/Tasks/Appointments Imported."

	end

	def transfer_products(appdata)

		puts "Importing Products..."

		#SOURCE APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#SOURCE APP DATA
		#_______________
		#get products, categories, and category assignments
		source_products = get_table('Product')
		source_product_categories = get_table('ProductCategory')
		source_category_assign = get_table('ProductCategoryAssign')
		source_subscription_plans = get_table('SubscriptionPlan')


		#DESTINATION APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes destination app
		initialize_infusionsoft(appdata[:dest_appname], appdata[:dest_apikey])

		#DEST APP DATA
		#_____________
		#get destination app products and categories to compare against source data, and stores them in hashes
		dest_products = {}
		get_table('Product').each do |prod|
			dest_products[prod['Id']] = prod['ProductName']
		end

		dest_product_categories = {}
		get_table('ProductCategory').each do |cat|
			dest_product_categories[cat['Id']] = cat['CategoryDisplayName']
		end

		dest_subscription_plans = get_table('SubscriptionPlan')

		#CREATE SUBSCRIPTIONS, PRODUCTS, AND CATEGORIES
		#______________________________
		#create products and categories if they don't exist by name in destination app
		product_relationships = {}
		source_products.each do |prod|
			product_relationships[prod['Id']] = dest_products.key(prod['ProductName']).nil? ? Infusionsoft.data_add('Product',prod) : dest_products.key(prod['ProductName'])
		end
		puts product_relationships.to_s

		source_subscription_plans.each do |sub|
			puts "Src Sub ID: #{sub['Id']}"
			do_not_import = false
			dest_subscription_plans.each do |plan|
				do_not_import = true if sub['PlanPrice'] == plan['PlanPrice'] && sub['NumberOfCycles'] == plan['NumberOfCycles'] && product_relationships[sub['ProductId']] == plan['ProductId']
				@@subscription_relationship[sub['Id']] = plan['Id'] if do_not_import
			end
			sub['ProductId'] = product_relationships[sub['ProductId']]
			do_not_import = true if sub['ProductId'].nil?
			@@subscription_relationship[sub['Id']] = Infusionsoft.data_add('SubscriptionPlan',sub) unless do_not_import
			puts "Sub ID #{sub['Id']} imported: #{do_not_import}"
		end

		category_relationships = {}
		source_product_categories.each do |cat|
			category_relationships[cat['Id']] = dest_product_categories.key(cat['CategoryDisplayName']).nil? ? Infusionsoft.data_add('ProductCategory',cat) : dest_product_categories.key(cat['CategoryDisplayName'])
		end

		#ATTACH PRODUCTS AND CATEGORIES
		#______________________________
		#add assignments to ProductCategoryAssign, matching Ids based on previously created relationship hashes
		dest_category_assign = get_table('ProductCategoryAssign')
		source_category_assign.each do |assign|
			do_not_import = false
			dest_category_assign.each do |cat|
				do_not_import = true if product_relationships[assign['ProductId']] == cat['ProductId'] && category_relationships[assign['ProductCategoryId']] == cat['ProductCategoryId']
			end
			Infusionsoft.data_add('ProductCategoryAssign',{'ProductId' => product_relationships[assign['ProductId']], 'ProductCategoryId' => category_relationships[assign['ProductCategoryId']]}) unless do_not_import
		end

		puts "Products Imported."

	end

	def transfer_opportunities(appdata)

		puts "Importing Opportunities..."

		#SOURCE APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#SOURCE APP DATA
		#_______________
		#get opportunities, custom fields, product interests, and product interest bundles
		source_app_custom_fields = get_table('DataFormField')
		opportunity_fields = []
		opportunity_fields = FIELDS['Lead'].map(&:clone)

		source_app_custom_fields.each do |customfield|
			opportunity_fields << ("_" + customfield['Name']) if customfield['FormId'] == -4
		end

		#gets source companies with custom fields.
		source_opportunities = get_table('Lead',opportunity_fields)

		#get source products, product interests, and interest bundles
		source_products = {}
		get_table('Product').each do |product|
			source_products[product['ProductName']] = product['Id']
		end
		source_interests = get_table('ProductInterest')
		source_bundles = get_table('ProductInterestBundle')

		#get source app users for owner assignment
		source_app_users = get_table('User')

		#get source app opportunity stages to match to destination app stages
		source_app_stages = get_table('Stage')

		#DESTINATION APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes destination app
		initialize_infusionsoft(appdata[:dest_appname], appdata[:dest_apikey])

		#DEST APP DATA
		#_____________
		#get contacts and companies from source app
		dest_contacts = {}
		get_table('Contact',['Id',@@source_app_contact_id]).each do |contact|
			dest_contacts[contact['Id']] = contact[@@source_app_contact_id].to_i
		end

		dest_companies = {}
		get_table('Company',['Id',@@source_app_account_id]).each do |company|
			dest_companies[company['Id']] = company[@@source_app_account_id].to_i
		end

		dest_default_stage = Infusionsoft.data_get_app_setting('Opportunity','defaultstage')

		#CREATE OPPORTUNITY CUSTOM FIELDS
		#____________________
		#get tab id for first opportunity custom field tab, then get header tab using that tab id
		custom_field_tab_id = Infusionsoft.data_query('DataFormTab',1000,0,{'FormId' => -4},['Id'])[0]['Id']
		custom_field_header_id = Infusionsoft.data_query('DataFormGroup',1000,0,{'TabId' => custom_field_tab_id},['Id'])[0]['Id']

		#create opportunity custom fields if they don't exist, and store the rename mapping in a hash for use later
		rename_mapping = {}
		source_app_custom_fields.each do |customfield|
			if customfield['FormId'] == -4
				rename_mapping['_' + customfield['Name']] = create_custom_field(customfield['Label'],custom_field_header_id,'Opportunity',DATATYPES[DATATYPE_IDS[customfield['DataType']]]['dataType'])
				customfieldid = Infusionsoft.data_query('DataFormField',1000,0,{ Label: customfield['Label'] },['Id'])[0]['Id']
				Infusionsoft.data_update_custom_field(customfieldid,{ 'Values' => customfield['Values'] }) if DATATYPES[DATATYPE_IDS[customfield['DataType']]]['hasValues'] == 'yes'  && customfield['Values'] != nil
			end
		end

		#RENAME OPPORTUNITY FIELDS TO MATCH CUSTOM FIELDS
		#____________________________________________
		source_app_opp_id = create_custom_field('Source App Opportunity ID',custom_field_header_id,'Opportunity','Text')
		rename_mapping['Id'] = source_app_opp_id
		source_opportunities.each_with_index do |item, pos|
			source_opportunities[pos].keys.each { |k| source_opportunities[pos][ rename_mapping[k] ] = source_opportunities[pos].delete(k).to_s if rename_mapping[k] }
		end

		#CREATE USER RELATIONSHIP
		#________________________
		users_relationship = create_user_relationship(source_app_users,get_table('User'))

		#CREATE OPPORTUNITY STAGE RELATIONSHIP
		#_____________________________________
		#takes source app stages, and matches those stages to destination app if the name and stage order are exactly the same.
		dest_stages = {}
		get_table('Stage').each do |dest_stage|
			source_app_stages.each do |src_stage|
				dest_stages[src_stage['Id']] = dest_stage['Id'] if src_stage['StageName'] == dest_stage['StageName'] && src_stage['StageOrder'] == dest_stage['StageOrder']
			end
		end

		#IMPORT OPPORTUNITIES
		#____________________
		#attaches opps to contacts or companies
		dest_opportunities = {}
		source_opportunities.each do |opp|
			opp['ContactID'] = dest_contacts.key(opp['ContactID']).nil? ? dest_companies.key(opp['ContactID']) : dest_contacts.key(opp['ContactID'])
			dest_stages[opp['StageID']].nil? ? opp['StageID'] = dest_default_stage : opp['StageID'] = dest_stages[opp['StageID']]
			users_relationship[opp['UserID']].nil? ? opp['UserID'] = 0 : opp['UserID'] = users_relationship[opp['UserID']]
			dest_opportunities[opp[source_app_opp_id].to_i] = Infusionsoft.data_add('Lead',opp)
		end

		#IMPORT PRODUCT BUNDLES AND INTERESTS
		#______________________
		#create relationship between source and dest products
		dest_products = {}
		get_table('Product').each do |product|
			dest_products[source_products[product['ProductName']]] = product['Id']
		end

		dest_bundles = {}
		get_table('ProductInterestBundle').each do |bundle|
			dest_bundles[bundle['BundleName']] = bundle['Id']
		end

		bundles_relationship = {}
		source_bundles.each do |bundle|
			bundles_relationship[bundle['Id']] = dest_bundles[bundle['BundleName']].nil? ? Infusionsoft.data_add('ProductInterestBundle',bundle) : dest_bundles[bundle['BundleName']]
		end

		source_interests.each do |interest|
			interest['ObjectId'] = bundles_relationship[interest['ObjectId']] if interest['ObjType'] == 'Bundle'
			interest['ObjectId'] = dest_opportunities[interest['ObjectId']] if interest['ObjType'] == 'Opportunity'
			interest['ProductId'] == 0 ? interest['SubscriptionPlanId'] = @@subscription_relationship[interest['SubscriptionPlanId']] : interest['ProductId'] = dest_products[interest['ProductId']]
			Infusionsoft.data_add('ProductInterest',interest) unless interest['ObjType'] == 'Action' || interest['ProductId'].nil?
		end

		puts "Opportunities Imported."

	end

	def transfer_attachments(appdata)
		puts "Importing attachments..."

		#SOURCE APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#GET SOURCE DATA
		#_______________
		source_file_table = get_table('FileBox')

		#gets a list of user IDs to ignore from the FileBox table, so we only import contact files and not user files
		users = []
		get_table('User').each do |user|
			users << user['Id']
		end

		#TRANSFER FILES
		#______________
		#goes through each of the files in the source app, and adds it individually to the destination app, keeping the file in memory instead of writing it
		supported_file_types = ['doc','docx','log','msg','pages','rtf','txt','wpd','wps','err','text','pwd','notes','xdl','wp','wp4','wp5','wp7','wsd','tif','tiff','gif','jpeg','jpg','jif','jiff','jp2','jpx','j2k','fpx','pcd','png','pdf','bmp','psd','pspimage','thm','yuv','csv','xlr','xls','xlsx','key','pps','ppt','pptx','xml','wav','wma','mp3','mp4','mid','qt','mov','movie','hdmov','mnv','flv','f4p','hdv','divx','mp4','mp4v','mpg','mpeg','mpeg4','mpeg1','rm','vob','wmv','wm','avi','m4v','gvi','m2ts']

		source_file_table.each do |file|
			#moves to the next file if:
			#file is not attached to any contact OR file is attached to a user
			#file is not a supported filetype --- TODO get full list of unsupported types
			next if (file['ContactId'] == 0) || (users.include? file['ContactId']) || (supported_file_types.exclude? file['Extension'])

			#get the file from the source app
			initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])
			file_data = Infusionsoft.file_get(file['Id'])

			#get the contact that the file is attached to (skip if contact doesn't exist)
			initialize_infusionsoft(appdata[:dest_appname], appdata[:dest_apikey])
			contact = Infusionsoft.data_query('Contact',1000,0,{@@source_app_contact_id => file['ContactId']},['Id'])
			next if contact == []
			contact_id = contact[0]['Id']

			#upload file
			Infusionsoft.file_upload(contact_id,file['FileName'].downcase,file_data)
		end

		puts "Attachments Imported."
	end

	def transfer_orders(appdata)
		puts "Importing orders..."

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes source app
		initialize_infusionsoft(appdata[:src_appname], appdata[:src_apikey])

		#GET SOURCE DATA
		#_______________
		puts "=> Getting Source Data..."

		#get Job, Invoice, InvoiceItem, and InvoicePayment tables
		source_jobs = get_table('Job')
		source_invoices = get_table('Invoice')
		source_invoice_items = get_table('InvoiceItem')
		source_invoice_payments = get_table('InvoicePayment')
		source_payments = get_table('Payment')
		source_payment_plans = get_table('PayPlan')
		source_payment_plan_items = get_table('PayPlanItem')

		source_products = {}
		get_table('Product').each do |product|
			source_products[product['ProductName']] = product['Id']
		end

		puts source_products

		#DESTINATION APP
		#-----------------------------------------------------------------------------

		#INITIALIZE INFUSIONSOFT
		#_______________________
		#initializes destination app
		initialize_infusionsoft(appdata[:dest_appname], appdata[:dest_apikey])

		#GET DEST DATA
		#_____________
		puts "=> Getting Destination Data..."

		#get contact relationship
		contact_ids_relationship = {}
		get_table('Contact',['Id',@@source_app_contact_id]).each do |contact|
			contact_ids_relationship[contact[@@source_app_contact_id].to_i] = contact['Id']
		end

		#create historical Job > Invoice relationship
		historical_job_invoice_relationship = {}
		source_invoices.each do |invoice|
			historical_job_invoice_relationship[invoice['JobId']] = invoice['Id']
		end

		#CREATE BLANK ORDERS
		#___________________
		puts "=> Creating Blank Orders..."

		#creates blank orders and stores relationship between the created Invoice and the historical invoice
		invoice_relationship = {}
		source_jobs.each do |job|
			next if (contact_ids_relationship[job['ContactId']].nil?) || (job['JobRecurringId'] != 0) #skips orders attached to users and subscription orders
			invoice_relationship[historical_job_invoice_relationship[job['Id']].to_i] = Infusionsoft.invoice_create_blank_order(contact_ids_relationship[job['ContactId']],job['JobTitle'],job['DueDate'],0,0)
		end

		#CREATE ORDER ITEMS
		#__________________
		puts "=> Creating Order Items..."

		#create relationship between invoices and purchased products
		historical_invoice_product_relationship = {}
		source_invoices.each do |invoice|
			next if invoice['ProductSold'].nil?
			historical_invoice_product_relationship[invoice['Id']] = invoice['ProductSold'].split(",").map(&:to_i)
		end

		#create product relationship
		dest_products = {}
		get_table('Product').each do |product|
			next if source_products[product['ProductName']].nil?
			dest_products[source_products[product['ProductName']]] = product['Id']
		end

		puts dest_products

		#create invoice items
		source_invoice_items.each do |item|
			invoice_id = invoice_relationship[item['InvoiceId']]
			next if invoice_id.nil? #skips invoices that weren't created, because they didn't have a contact to attach to, or if they were subscription orders
			historical_invoice_product_relationship[item['InvoiceId']].nil? ? product_id = 0 : product_id = dest_products[historical_invoice_product_relationship[item['InvoiceId']].shift]
			product_id.nil? ? product_type = 0 : product_type = 4
			product_id = 0 if product_id.nil?
			match = /\(Qty (\d+)\)/.match(item['Description'])
			match.nil? ? quantity = 1 : quantity = match.captures[0].to_i
			price = item['InvoiceAmt'].to_f / quantity
			description = item['Description']
			puts "Invoice Id: #{invoice_id}\nProduct Id: #{product_id}\nProduct Type: #{product_type}\nPrice: #{price}\nQuantity: #{quantity}\nDescription: #{description}\n"
			Infusionsoft.invoice_add_order_item(invoice_id,product_id,product_type,price.to_f,quantity,description,'')
		end

		puts "Orders Imported."
	end
end
