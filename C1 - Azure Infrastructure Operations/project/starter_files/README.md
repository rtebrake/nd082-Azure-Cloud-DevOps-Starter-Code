# Azure Infrastructure Operations Project: Deploying a scalable IaaS web server in Azure

### Introduction
This project consists of a Packer template and a Terraform template to deploy a customizable, scalable web server in Azure.

### Dependencies
1. Create an [Azure Account](https://portal.azure.com) 
2. Install the [Azure command line interface](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
3. Install [Packer](https://www.packer.io/downloads)
4. Install [Terraform](https://www.terraform.io/downloads.html)

### Instructions

Create a Service Principal using the [instructions](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret).

Set the following environment variables,using the AppID and Password from the Service Principal as the ARM_CLIENT_id AND ARM_CLIENT_SECRET respectively. The link above also contains details on how to retrieve the values needed for ARM_SUBSCRIPTION_ID and ARM_TENANT_ID.

>ARM_CLIENT_ID  
>ARM_CLIENT_SECRET  
>ARM_SUBSCRIPTION_ID  
>ARM_TENANT_ID  

The Terraform template requires a customized Ubuntu Linux image which will act as the template for the virtual machines. This customized image is built using Packer. Use the steps below to create this image.

>Note: There is a variable defined in the Terraform template that refers to the location of the Packer image. This value can be changed but by default this will be 'k45-image-rg' and it needs to exist for Packer to succesfully build the image.

1. Create the Resource Group 'k45-image-rg', this can be done using the Azure Portal or the Azure CLI for example. 
2. Use the server.json file together with the Packer download and execute the following:
    packer validate server.json
    packer build server.json
    
The 'validate' step should produce no results, this is expected. The 'build' step will create a (temporary) resource group and virtual machine to customize our image based on the Packer instructions.

After Packer has completed it's customization, it will have a created an Image resource called 'UbuntuImage' in our Azure subscription. This is the Image that is needed to deploy the Terraform template in the following steps.

Terraform needs the main.tf and vars.tf to be able to deploy the environment succesfully.
Use these files together with the Terraform executable and follow the steps below.

Note: the default configuration of the Terraform template deploys 2 virtual machines in the West Europe region. These variables are configurable and changing these is covered further down this document.

Execute the following to deploy the Terraform template:
1. terraform init
2. terraform plan
3. terraform apply

The 'apply' step will require confirmation by typing 'yes' at the prompt. This can be skipped by adding the -auto-approve parameter.


### Output

The end result of running both the Packer and Terraform template should be the following:

1. A Linux VM image, based on Ubuntu 18.04 LTS, updated (*apt-get update,apt-get upgrade*) with Nginx installed and running with a default homepage ('Hello World'). This Image is visible as a Managed Image in the Azure subscription.
2. A deployment of 2 virtual machines based on the image of the previous step, running in an Availability Set. These virtual machines have additional Managed Disks as datadisks.
3. An Azure Load Balancer, reachable through a Public IP and using the virtual machines as the backend. The Load Balancer is configured with both a load balancing rule and a HealthProbe.
4. A virtual network containing a subnet, protected by a Network Security Group allowing Inbound Port 80, VNet-internal traffic but also has an explicit deny for traffic originating from the Internet.


### Customizing the deployment

There are several variables defined in a seperate file, *vars.tf*, that allow for easy customization of the deployment.

*prefix* - The prefix is used to generate (unique) resource names as part of the deployment.  
*location* - The Azure location in which all resources and the resource group are created  
*vm_count* - The number of virtual machines deployed. By default this is set at 2, which is the minimum. The maximum value allowed is 5. Values outside of these ranges are rejected.  
*custom_image_resource_group_name* - The name of the resource group in which the Packer Image can be found. Default is *k45-image-rg*.  
*custom_image_name* - The name of the image created by Packer, default is 'UbuntuImage'.  
  
>Note: In the vars.tf there is also a variable definition 'default_tags'. Even though it can be used to easily update the tags for all the resources deployed, the main purpose of defining the Azure Resource Tags using a variable is readability of the main.tf file. Applying tags to those Terraform resources that support it is now handled by a single line of code (tags = var.default_tags) instead of 3 or more.
