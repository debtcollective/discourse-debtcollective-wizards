# name: discourse-debtcollective-wizards
# about: A plugin that holds our custom wizards logic
# version: 0.0.1

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

      def send_solidarity_pm(user)
        PostCreator.create(Discourse.system_user,
          archetype: Archetype.private_message,
          title: "Joining in solidarity",
          raw: pm_content(user),
          target_usernames: [user.username],
          target_group_names: ["team"]
        )
      end

      private

      def pm_content(user)
        <<~CONTENT
          Hello @#{user.username}!

          We want to say thank you for joining wanting to help The Debt Collective. What skills you think you can contribute with to our cause?

          Thanks!
        CONTENT
      end
    end
  end

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

    raise "You need to select at least one" if groups_to_join.empty?

    DebtCollective.add_user_to_groups(user, groups)
    DebtCollective.send_solidarity_pm(user) if groups_to_join.include?('solidarity_bloc')
  end
end
