provider "azurerm" {
    features {}
}

# Create a resource group
resource "azurerm_resource_group" "project1" {
    name    = "${var.prefix}-rg"
    tags = var.default_tags
    location = var.location
}

# Create a virtual network
resource "azurerm_virtual_network" "project1" {
    name = "${var.prefix}-network"
    tags = var.default_tags
    address_space = ["10.0.0.0/16"]
    location = azurerm_resource_group.project1.location
    resource_group_name = azurerm_resource_group.project1.name
}

# Create a subnet
resource "azurerm_subnet" "internal" {
    name = "internal"
    resource_group_name = azurerm_resource_group.project1.name
    virtual_network_name = azurerm_virtual_network.project1.name
    address_prefixes = ["10.0.2.0/24"]
}

# Create a NSG
resource "azurerm_network_security_group" "project1" {
    location = azurerm_resource_group.project1.location
    resource_group_name = azurerm_resource_group.project1.name
    name = "${var.prefix}-nsg"
    tags = var.default_tags

    security_rule{
        name                        = "Custom-Internet-Port80-rule"
        priority                    = 100
        direction                   = "Inbound"
        access                      = "Allow"
        protocol                    = "tcp"
        source_port_range           = "*"
        destination_port_range      = "80"
        source_address_prefix       = "Internet"
        destination_address_prefix  = "VirtualNetwork"
    }

    security_rule{
        name                        = "Custom-Vnet-to-Vnet-rule"
        priority                    = 110
        direction                   = "Inbound"
        access                      = "Allow"
        protocol                    = "tcp"
        source_port_range           = "*"
        destination_port_range      = "*"
        source_address_prefix       = "VirtualNetwork"
        destination_address_prefix  = "VirtualNetwork"
    }

    security_rule{
        name                        = "Custom-Internet-deny-all"
        priority                    = 120
        direction                   = "Inbound"
        access                      = "Deny"
        protocol                    = "tcp"
        source_port_range           = "*"
        destination_port_range      = "*"
        source_address_prefix       = "Internet"
        destination_address_prefix  = "VirtualNetwork"
    }
}

# Associate the NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "project1" {
    subnet_id = azurerm_subnet.internal.id
    network_security_group_id = azurerm_network_security_group.project1.id
}

# Claim a Public IP to be used by the Load Balancer (Front End)
resource "azurerm_public_ip" "project1-lb" {
    name = "${var.prefix}-pip"
    tags = var.default_tags
    resource_group_name = azurerm_resource_group.project1.name
    location = azurerm_resource_group.project1.location
    allocation_method = "Dynamic"
    sku = "Basic"
}

# Create the Load Balancer and attach the Public IP
resource "azurerm_lb" "project1-lb" {
    name = "${var.prefix}-lb"
    tags = var.default_tags
    resource_group_name = azurerm_resource_group.project1.name
    location = azurerm_resource_group.project1.location

    frontend_ip_configuration {
        name = "${var.prefix}-lb-frontend"
        public_ip_address_id = azurerm_public_ip.project1-lb.id
    }
}

# Create the Backend Address Pool for the load balancer
resource "azurerm_lb_backend_address_pool" "project1-lb-be" {
     resource_group_name = azurerm_resource_group.project1.name
     loadbalancer_id   = azurerm_lb.project1-lb.id
     name = "BackEndAddressPool"
}

# Create a Load Balancing rule
resource "azurerm_lb_rule" "project1-lb-rule" {
    resource_group_name = azurerm_resource_group.project1.name
    loadbalancer_id   = azurerm_lb.project1-lb.id
    name                           = "LB-Port80-rule"
    protocol                       = "tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = "${var.prefix}-lb-frontend"
    enable_floating_ip             = false
    backend_address_pool_id        = azurerm_lb_backend_address_pool.project1-lb-be.id
    idle_timeout_in_minutes        = 5
    probe_id                       = azurerm_lb_probe.lb_probe.id
}

# Add a Load Balancer Probe to determine endpoint health status
resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = azurerm_resource_group.project1.name
  loadbalancer_id = azurerm_lb.project1-lb.id
  name = "Port80Probe"
  protocol = "tcp"
  port = 80
  interval_in_seconds = 5
  number_of_probes = 2
}

# Create an Availability Set for the VM(s) 
resource "azurerm_availability_set" "project1" {
    name = "${var.prefix}-as"
    tags = var.default_tags
    resource_group_name = azurerm_resource_group.project1.name
    location = azurerm_resource_group.project1.location

}

# Create network interfaces for VMs
resource "azurerm_network_interface" "project1" {
  count = var.vm_count
  name = "${var.prefix}-nic${count.index}"
  tags = var.default_tags
  resource_group_name = azurerm_resource_group.project1.name
  location = azurerm_resource_group.project1.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Add the network interfaces to the Load Balancer Backend Address Pool
resource "azurerm_network_interface_backend_address_pool_association" "project1-lb" {
    count = var.vm_count
    network_interface_id = azurerm_network_interface.project1[count.index].id
    ip_configuration_name = "primary"
    backend_address_pool_id = azurerm_lb_backend_address_pool.project1-lb-be.id
}

# Packer image
data "azurerm_image" "image" {
  name = var.custom_image_name
  resource_group_name = var.custom_image_resource_group_name
}

# Deploy virtual machines
resource "azurerm_linux_virtual_machine" "project1" {
    count = var.vm_count
    name = "${var.prefix}-vm${count.index}"
    tags = var.default_tags
    resource_group_name = azurerm_resource_group.project1.name
    location = azurerm_resource_group.project1.location
    size = "Standard_D2s_v3"
    availability_set_id = azurerm_availability_set.project1.id

    source_image_id = data.azurerm_image.image.id
    
    admin_username                  = "adminuser"
    admin_password                  = "P@ssw0rd1234!"
    disable_password_authentication = false


    network_interface_ids = [
        azurerm_network_interface.project1[count.index].id,
    ]
       
    os_disk {
        name              = ""
        caching           = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }
  }

# Create Managed disks to be added to the VMs
resource "azurerm_managed_disk" "datadisk" {
    count = var.vm_count    
    name = "${var.prefix}-disk${count.index}"
    tags = var.default_tags
    location = azurerm_resource_group.project1.location

    resource_group_name = azurerm_resource_group.project1.name
    create_option = "Empty"
    disk_size_gb = 10
    storage_account_type = "Standard_LRS"
}

resource "azurerm_virtual_machine_data_disk_attachment" "datadisk_attach" {
    count = var.vm_count  
    managed_disk_id    = azurerm_managed_disk.datadisk.*.id[count.index]
    virtual_machine_id = azurerm_linux_virtual_machine.project1.*.id[count.index]
    lun                = 0
    caching            = "None"
}