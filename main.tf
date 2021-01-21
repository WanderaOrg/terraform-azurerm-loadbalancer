# Azure load balancer module
resource "azurerm_public_ip" "azlb" {
  for_each = var.type == "public" ? {"${var.prefix}" = {}} : {}

  name                = "${each.key}-publicIP"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.public_ip_allocation_method
  tags                = var.tags
}

resource "azurerm_lb" "azlb" {
  name                = "${var.prefix}-lb"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  frontend_ip_configuration {
    name                          = var.frontend_name
    public_ip_address_id          = var.type == "public" ? azurerm_public_ip.azlb[var.prefix].id : ""
    subnet_id                     = var.frontend_subnet_id
    private_ip_address            = var.frontend_private_ip_address
    private_ip_address_allocation = var.frontend_private_ip_address_allocation
  }
}

resource "azurerm_lb_backend_address_pool" "azlb" {
  resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.azlb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_rule" "azlb" {
  for_each = var.remote_port

  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.azlb.id
  name                           = "VM-${each.key}"
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  frontend_ip_configuration_name = var.frontend_name
}

resource "azurerm_lb_probe" "azlb" {
  for_each = var.lb_port

  resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.azlb.id
  name                = each.key
  protocol            = each.value.protocol
  port                = each.value.backend_port
  interval_in_seconds = var.lb_probe_interval
  number_of_probes    = var.lb_probe_unhealthy_threshold
}

resource "azurerm_lb_rule" "azlb" {
  for_each = var.lb_port

  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.azlb.id
  name                           = each.key
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  frontend_ip_configuration_name = var.frontend_name
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.azlb.id
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.azlb[each.key].id

  depends_on = [azurerm_lb_probe.azlb]
}
