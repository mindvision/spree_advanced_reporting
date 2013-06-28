class Spree::AdvancedReport::DailyDetailsReport < Spree::AdvancedReport::IncrementReport
  attr_accessor :date, :shipments, :adjustments, :orders, :payments

  def name
    "Detailed Units Sold"
  end

  def column
    "Detailed Units"
  end

  def description
    "Total units sold in orders, a sum of the item quantities per order or per item"
  end

  def initialize(params)
    super(params)

    results = products_for_date(date)
    date = params[:date] ? Date.parse(params[:date]) : Date.today

    self.date = date
    self.data = results[:products]
    self.shipments = results[:shipments]
    self.adjustments = results[:adjustments]
    self.orders = results[:orders]
    self.payments = results[:payments]

  end

  def products_for_date2(date)
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    date_hash = {created_at: date.beginning_of_day..date.end_of_day}

    units = Spree::InventoryUnit.joins(:order, :shipment).where("shipment_id is not null").where(date_hash).where('spree_orders' => {state: 'complete'})

    products = {}
    units.each do |u|
      products[u.variant] ||= {price: 0, count: 0}
      products[u.variant][:price] += u.variant.price
      products[u.variant][:count] += 1
    end

    shipments = units.collect{|u| u.shipment}.uniq
    adjustments = Spree::Adjustment.where(date_hash).where("spree_adjustments.source_type != 'Spree::Shipment' OR spree_adjustments.source_type IS NULL")

    [products, shipments, adjustments]
  end

  def products_for_date(date)
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    conditions = {created_at: date.beginning_of_day..date.end_of_day, state: 'completed'}

    payments = Spree::Payment.joins(:order).where(conditions).where('spree_orders.completed_at is not null').includes(order: [:shipments, :adjustments])
    orders = payments.collect{|p| p.order}.uniq
    shipments = orders.collect(&:shipments).flatten
    adjustments = orders.collect(&:adjustments).flatten.select{|a| a.source_type != 'Spree::Shipment'}

    line_items = orders.collect(&:line_items).flatten

    products = line_items.reduce({}) do |memo, item|
      memo[item.variant] ||= {amount: 0, quantity: 0}
      memo[item.variant][:amount] += item.amount
      memo[item.variant][:quantity] += item.quantity
      memo
    end

    {products: products, shipments: shipments, adjustments: adjustments, orders: orders, payments: payments}
  end


  # This is a placeholder for logic that determines how many items in an order were actually shipped.
  # It may never be used again

  def items_shipped_from_an_order
    # For each order, determine how many 
    items = {}
    orders.each do |o|
      shipped_variants = o.inventory_units.collect{|i| i.variant}
      o.line_items.each do |i|
        variant = i.variant
        quantity = shipped_variants.count(variant)
        items[variant] ||= {count: 0, price: 0}
        items[variant][:count] += 1
        items[variant][:price] += i.price * quantity
      end
    end

    [items, shipments, adjustments]
  end

end
