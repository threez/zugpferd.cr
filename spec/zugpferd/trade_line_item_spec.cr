require "../spec_helper"

describe Zugpferd::SupplyChainTradeLineItem do
  it "auto-calculates line_total from quantity * net_price" do
    item = Zugpferd::SupplyChainTradeLineItem.new(
      position: 1,
      name: "Widget",
      billed_quantity: BigDecimal.new("3"),
      unit_code: "C62",
      net_price: BigDecimal.new("10.50"),
      tax_category_code: Zugpferd::ApplicableTradeTax::CategoryCode::S
    )
    item.line_total.should eq(BigDecimal.new("31.50"))
  end

  it "stores optional fields" do
    item = Zugpferd::SupplyChainTradeLineItem.new(
      position: 2,
      name: "Service",
      billed_quantity: BigDecimal.new("1"),
      unit_code: "HUR",
      net_price: BigDecimal.new("100"),
      tax_category_code: Zugpferd::ApplicableTradeTax::CategoryCode::S,
      description: "Hourly consulting",
      seller_assigned_id: "SVC-001"
    )
    item.description.should eq("Hourly consulting")
    item.seller_assigned_id.should eq("SVC-001")
  end
end
