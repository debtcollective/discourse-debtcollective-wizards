# name: discourse-debtcollective-wizards
# about: A plugin that holds our custom wizards logic
# version: 0.0.1

enabled_site_setting :debtcollective_wizards_enabled

after_initialize do
  class DebtCollective
    class << self
      def collectives
        @collectives ||= [
          "court_fines_and_fees",
          "student_debt",
          "housing_debt",
          "auto_loans",
          "payday_loans",
          "medical_debt",
          "for_profit_colleges",
          "credit_card_debt",
          "solidarity_bloc"
        ]
      end

      def add_user_to_groups(user, groups)
        groups.each do |group_name, is_member|
          group = Group.find_by(name: group_name)

          if is_member
            group.add(user)
          else
            group.remove(user)
          end

          group.save
        end
      end

      def solidarity_pm_content(user)
        "Hello @#{user.username}!\n\nThank you for offering to help in solidarity with people in debt. Tell us a little about yourself and what skills you have to share so we can get started."
      end

      def send_solidarity_pm(user)
        bloc_manager = User.find_by_username(SiteSetting.debtcollective_solidarity_message_author)
        bloc_manager ||= Discourse.system_user

        PostCreator.create(bloc_manager,
          archetype: Archetype.private_message,
          title: SiteSetting.debtcollective_solidarity_message_title,
          raw: solidarity_pm_content(user),
          target_usernames: [user.username],
          target_group_names: []
        )
      end
    end
  end

  # Registering User profile fields
  User.register_custom_field_type('phone_number', :text)
  User.register_custom_field_type('zip', :text)

  # welcome wizard step handler
  # we only process the 'debt_types' step
  CustomWizard::Builder.add_step_handler('welcome') do |builder|
    current_step = builder.updater.step
    updater = builder.updater
    wizard = builder.wizard
    user = wizard.user

    next unless current_step.id == "debt_types"

    # fields returns an ActiveParams object
    # we cast it as hash
    step_data = updater.fields.to_h

    groups = step_data.slice(*DebtCollective.collectives)
    groups_to_join = groups.select { |key, value| groups[key] == true }

    if groups_to_join.empty?
      # we use the wizard id as field for the error to be shown as a step error
      updater.errors.add(wizard.id, "You must select at least one")
      next
    end

    DebtCollective.add_user_to_groups(user, groups)
    DebtCollective.send_solidarity_pm(user) if groups_to_join.include?('solidarity_bloc')
  end
end
