# Sku Documentation
#
# The Sku table manages all the product variations. The Sku column value is automatically generated by the product SKU being combined with
# the attribute_value field. Each attribute value is unique within its parent product, and each SKU is unique globally.
# Product table utitlises the Sku table in order to create an easy and scalable database. 

# == Schema Information
#
# Table name: skus
#
#  id                         :integer          not null, primary key
#  code                       :string(255)      
#  length                     :decimal          precision(8), scale(2) 
#  weight                     :decimal          precision(8), scale(2) 
#  thickness                  :decimal          precision(8), scale(2) 
#  attribute_value            :string(255) 
#  attribute_type_id          :integer 
#  stock                      :integer 
#  stock_warning_level        :integer 
#  cost_value                 :decimal          precision(8), scale(2) 
#  price                      :decimal          precision(8), scale(2) 
#  product_id                 :integer 
#  active                     :boolean          default(true)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
class Sku < ActiveRecord::Base
  
  attr_accessible :cost_value, :price, :code, :stock, :stock_warning_level, :length, 
  :weight, :thickness, :product_id, :attribute_value, :attribute_type_id, :accessory_id, :active
  
  has_many :cart_items
  has_many :carts,                                                    :through => :cart_items
  has_many :order_items,                                              :dependent => :restrict_with_exception
  has_many :orders,                                                   :through => :order_items, :dependent => :restrict_with_exception
  has_many :notifications,                                            as: :notifiable, :dependent => :delete_all
  has_many :stock_levels,                                             :dependent => :delete_all
  belongs_to :product,                                                inverse_of: :skus
  belongs_to :attribute_type

  validates :price, :cost_value, :length, 
  :weight, :thickness, :code,                                         :presence => true
  validates :price, :cost_value,                                      :format => { :with => /\A(\$)?(\d+)(\.|,)?\d{0,2}?\z/ }
  validates :length, :weight, :thickness,                             :numericality => { :greater_than_or_equal_to => 0 }
  validates :stock, :stock_warning_level,                             :presence => true, :numericality => { :only_integer => true, :greater_than_or_equal_to => 1 }
  validate :stock_values,                                             :on => :create
  validates :attribute_value, :code,                                  :uniqueness => { :scope => [:product_id, :active] }
  validates :attribute_value, :attribute_type_id,                     presence: true, :if => :not_single_sku?

  after_update :update_cart_items_weight

  # Validation check to ensure the stock value is higher than the stock warning level value when creating a new SKU
  #
  # @return [Boolean]
  def stock_values
    if self.stock && self.stock_warning_level && self.stock <= self.stock_warning_level
      errors.add(:sku, "stock warning level value must not be below your stock count.")
      return false
    end
  end
  
  # Grabs an array of records which have their active field set to true
  #
  # @return [Array] list of active skus
  def self.active
    where(['skus.active = ?', true])
  end

  # If the record's weight has changed, update all associated cart_items records with the new weight
  #
  def update_cart_items_weight
    cart_items = CartItem.where(:sku_id => id)
    cart_items.each do |item|
      item.update_column(:weight, (weight*item.quantity))
    end
  end

  # Validates the attribute_value and attribute_type_id if there is only one SKU associated with product
  # and the product has been set to single
  # The standard self.skus.count is performed using the record ID, which none of the SKUs currently have
  # so the count is completed using the active field being set to true
  #
  # @return [Boolean]
  def not_single_sku?
    return self.product && self.product.skus.map { |s| s.active }.count == 1 && self.product.single ? false : true
  end

  # Joins the parent product SKU and the current SKU with a hyphen
  #
  # @return [String] product SKU and current SKU concatenated
  def full_sku
    [product.sku, code].join('-')
  end

end
