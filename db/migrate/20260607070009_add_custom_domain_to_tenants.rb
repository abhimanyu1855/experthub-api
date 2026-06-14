class AddCustomDomainToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :custom_domain, :string
    add_column :tenants, :custom_domain_status, :string, default: "pending"
    add_column :tenants, :dns_txt_record, :string

    add_index :tenants, :custom_domain, unique: true, where: "custom_domain IS NOT NULL"
  end
end
