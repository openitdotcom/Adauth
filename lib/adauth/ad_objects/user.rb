module Adauth
    module AdObjects
        # Active Directory User Object
        #
        # Inherits from Adauth::AdObject
        class User < Adauth::AdObject
            # Field mapping
            #
            # Maps methods to LDAP fields e.g.
            #
            # :foo => :bar
            #
            # Becomes
            # 
            # Computer.name
            #
            # Which calls .name on the LDAP object
            Fields = { :login => :samaccountname,
                    :first_name => :givenname,
                    :last_name => :sn,
                    :email => :mail,
                    :name => :name,
                    :cn_groups => [ :memberof,
                        Proc.new {|g| g.sub(/.*?CN=(.*?),.*/, '\1').to_s} ]
                    }
              
            # Object Net::LDAP filter
            #
            # Used to restrict searches to just this object      
            ObjectFilter = Net::LDAP::Filter.eq('objectClass', 'user')
          
            # Returns a connection to AD within the users context, used to check a user credentails
            #
            # Using this would by pass the group and OU Filtering provided by Adauth#authenticate
            def self.authenticate(user, password)
                user_connection = Adauth::Connection.new(Adauth.connection_hash(user, password)).bind
            end
            
            # Returns True/False if the user is member of the supplied group
            def member_of?(group)
                cn_groups.include?(group)
            end
            
            # Changes the password to the supplied value
            def set_password(new_password)
              Adauth.logger.info("password management") { "Attempting password reset for #{self.login}" }
              password = microsoft_encode_password(new_password)
              modify([[:replace, :unicodePwd, password]])
            end
            
            # Add the user to the supplied group
            def add_to_group(group)
              expects group, Adauth::AdObjects::Group
              group.modify([[:add, :member, @ldap_object.dn]])
            end
            
            # Remove the user from the supplied group
            def remove_from_group(group)
              expects group, Adauth::AdObjects::Group
              group.modify([[:delete, :member, @ldap_object.dn]])
            end
            
            def cn_nested_groups
			        @cngroups_nested = cn_groups
              cn_groups.each do |group|
		          
                ado = Adauth::AdObjects::Group.where('name', group).first
                if ado
                  groups = ado.cn_groups.reject { |c| c.empty? } rescue []
                  groups = Adauth::AdObjects.convert_to_objects groups rescue []
                  groups.each do |g|
                    if !(@cngroups_nested.include?(g))
					            @cngroups_nested.push g
                      Adauth.logger.info("cn_nested_groups") { "Adding #{g} to the nested groups" }
                    end
                  end
                end
              end
			        return  @cngroups_nested
			      end
            
            private
            
            def microsoft_encode_password(password)
              out = ""
              password = "\"" + password + "\""
              password.length.times{|i| out+= "#{password[i..i]}\000" }
              return out
            end
        end
    end
end
