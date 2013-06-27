class Spree::AdvancedReport::DailyDetailsReport < Spree::AdvancedReport::IncrementReport
  attr_accessor :date, :shipments, :adjustments

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

    date = params[:date] ? Date.parse(params[:date]) : Date.today
    date_hash = {created_at: date.beginning_of_day..date.end_of_day}

    units = Spree::InventoryUnit.joins(:order, :shipment).where("shipment_id is not null").where(date_hash).where('spree_orders' => {state: 'complete'})

    products = {}
    units.each do |u|
      products[u.variant] ||= {price: 0, count: 0}
      products[u.variant][:price] += u.variant.price
      products[u.variant][:count] += 1
    end

    self.shipments = units.collect{|u| u.shipment}.uniq
    self.adjustments = Spree::Adjustment.where(date_hash).where("spree_adjustments.source_type != 'Spree::Shipment' OR spree_adjustments.source_type IS NULL")

    self.date = date
    self.data = products

  end
end
