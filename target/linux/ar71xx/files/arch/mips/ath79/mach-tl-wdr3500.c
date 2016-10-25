/*
 *  TP-LINK TL-WDR3500 board support
 *
 *  Copyright (C) 2012 Gabor Juhos <juhosg@openwrt.org>
 *  Copyright (C) 2013 Gui Iribarren <gui@altermundi.net>
 *
 *  This program is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License version 2 as published
 *  by the Free Software Foundation.
 */

#include <linux/pci.h>
#include <linux/phy.h>
#include <linux/gpio.h>
#include <linux/platform_device.h>
#include <linux/ath9k_platform.h>
#include <linux/ar8216_platform.h>
#include <linux/mmc/host.h>
#include <linux/spi/spi.h>
#include <linux/spi/mmc_spi.h>

#include <asm/mach-ath79/ar71xx_regs.h>

#include "common.h"
#include "dev-ap9x-pci.h"
#include "dev-eth.h"
#include "dev-gpio-buttons.h"
#include "dev-leds-gpio.h"
#include "dev-m25p80.h"
#include "dev-spi.h"
#include "dev-usb.h"
#include "dev-wmac.h"
#include "machtypes.h"

//#define WDR3500_GPIO_LED_USB		11
//#define WDR3500_GPIO_LED_WLAN2G		13
//#define WDR3500_GPIO_LED_SYSTEM		14
//#define WDR3500_GPIO_LED_QSS		15
#define WDR3500_GPIO_LED_BAR0		48
#define WDR3500_GPIO_LED_BAR1		49
#define WDR3500_GPIO_LED_BAR2		50
#define WDR3500_GPIO_LED_BAR3		51
#define WDR3500_GPIO_LED_BAR4		52
#define WDR3500_GPIO_LED_ST_GRE		53
#define WDR3500_GPIO_LED_ST_RED		54
//#define WDR3500_GPIO_LED_WAN		18
#define WDR3500_GPIO_LED_LAN1		14
#define WDR3500_GPIO_LED_LAN2		13
#define WDR3500_GPIO_LED_LAN3		22
#define WDR3500_GPIO_LED_LAN4		20

#define WDR4300_GPIO_EXTERNAL_LNA0	2
#define WDR4300_GPIO_EXTERNAL_LNA1	3

//#define WDR3500_GPIO_BTN_WPS		16
//#define WDR3500_GPIO_BTN_RFKILL		17
#define WDR3500_GPIO_BTN_RESET		17
#define WDR3500_GPIO_BTN_EXPANDER	4
#define WDR3500_GPIO_BTN_TEST		58
#define WDR3500_GPIO_MMC_CS		11

//#define WDR3500_GPIO_EXPANDER_POWER	11

#define WDR3500_KEYS_POLL_INTERVAL	20	/* msecs */
#define WDR3500_KEYS_DEBOUNCE_INTERVAL	(3 * WDR3500_KEYS_POLL_INTERVAL)

#define WDR3500_MAC0_OFFSET		0
#define WDR3500_MAC1_OFFSET		6
#define WDR3500_WMAC_CALDATA_OFFSET	0x1000
#define WDR3500_PCIE_CALDATA_OFFSET	0x5000

static const char *wdr3500_part_probes[] = {
	"tp-link",
	NULL,
};

static struct flash_platform_data wdr3500_flash_data = {
	.part_probes	= wdr3500_part_probes,
};

static struct gpio_led wdr3500_leds_gpio[] __initdata = {
	/*{
		.name		= "tp-link:green:qss",
		.gpio		= WDR3500_GPIO_LED_QSS,
		.active_low	= 1,
	},*/
	/*{
		.name		= "tp-link:green:system",
		.gpio		= WDR3500_GPIO_LED_SYSTEM,
		.active_low	= 1,
	},*/
	/*{
		.name		= "tp-link:green:usb",
		.gpio		= WDR3500_GPIO_LED_USB,
		.active_low	= 1,
	},*/
	/*{
		.name		= "tp-link:green:wlan2g",
		.gpio		= WDR3500_GPIO_LED_WLAN2G,
		.active_low	= 1,
	},*/
	{
		.name		= "signal_bar0",
		.gpio		= WDR3500_GPIO_LED_BAR0,
		.active_low	= 0,
	},
	{
		.name		= "signal_bar1",
		.gpio		= WDR3500_GPIO_LED_BAR1,
		.active_low	= 0,
	},
	{
		.name		= "signal_bar2",
		.gpio		= WDR3500_GPIO_LED_BAR2,
		.active_low	= 0,
	},
	{
		.name		= "signal_bar3",
		.gpio		= WDR3500_GPIO_LED_BAR3,
		.active_low	= 0,
	},
	{
		.name		= "signal_bar4",
		.gpio		= WDR3500_GPIO_LED_BAR4,
		.active_low	= 0,
	},
	{
		.name		= "status_green",
		.gpio		= WDR3500_GPIO_LED_ST_GRE,
		.active_low	= 0,
	},
	{
		.name		= "status_red",
		.gpio		= WDR3500_GPIO_LED_ST_RED,
		.active_low	= 0,
	},

};

static struct gpio_keys_button wdr3500_gpio_keys[] __initdata = {
	/*{
		.desc		= "QSS button",
		.type		= EV_KEY,
		.code		= KEY_WPS_BUTTON,
		.debounce_interval = WDR3500_KEYS_DEBOUNCE_INTERVAL,
		.gpio		= WDR3500_GPIO_BTN_WPS,
		.active_low	= 1,
	},*/
	/*{
		.desc		= "RFKILL switch",
		.type		= EV_SW,
		.code		= KEY_RFKILL,
		.debounce_interval = WDR3500_KEYS_DEBOUNCE_INTERVAL,
		.gpio		= WDR3500_GPIO_BTN_RFKILL,
	},*/
	{
		.desc		= "Reset button",
		.type		= EV_KEY,
		.code		= KEY_RESTART,
		.debounce_interval = WDR3500_KEYS_DEBOUNCE_INTERVAL,
		.gpio		= WDR3500_GPIO_BTN_RESET,
		.active_low	= 1,
	},
	{
		.desc		= "Expander interrupt",
		.type		= EV_KEY,
		.code		= KEY_RFKILL,
		.debounce_interval = WDR3500_KEYS_DEBOUNCE_INTERVAL,
		.gpio		= WDR3500_GPIO_BTN_EXPANDER,
	},
};

static struct ath79_spi_controller_data ath79_spi0_cdata =
{
	.cs_type = ATH79_SPI_CS_TYPE_INTERNAL,
	.cs_line = 0,
	.is_flash = true,
};

static struct ath79_spi_controller_data ath79_spi1_cdata =
{
	.cs_type = ATH79_SPI_CS_TYPE_INTERNAL,
	.cs_line = 1,
};

static struct spi_board_info ath79_spi_info[] = {
	{
		.bus_num	= 0,
		.chip_select	= 0,
		.max_speed_hz	= 25000000,
		.modalias	= "m25p80",
		.controller_data = &ath79_spi0_cdata,
		.platform_data	= &wdr3500_flash_data,
	},
	{
		.bus_num	= 0,
		.chip_select	= 1,
		.max_speed_hz   = 25000000,
		.modalias	= "mmc_spi",
		.controller_data = &ath79_spi1_cdata,
	}
};

static struct ath79_spi_platform_data ath79_spi_data = {
	.bus_num 	= 0,
	.num_chipselect	= 2,
};

static void __init wdr3500_setup(void)
{
	u8 *mac = (u8 *) KSEG1ADDR(0x1f01fc00);
	u8 *art = (u8 *) KSEG1ADDR(0x1fff0000);
	u8 tmpmac[ETH_ALEN];

	//ath79_register_m25p80_multi(&wdr3500_flash_data);
	ath79_register_spi(&ath79_spi_data, ath79_spi_info, 2);
	ath79_register_leds_gpio(-1, ARRAY_SIZE(wdr3500_leds_gpio),
				 wdr3500_leds_gpio);
	ath79_register_gpio_keys_polled(-1, WDR3500_KEYS_POLL_INTERVAL,
					ARRAY_SIZE(wdr3500_gpio_keys),
					wdr3500_gpio_keys);
					
	ath79_wmac_set_ext_lna_gpio(0, WDR4300_GPIO_EXTERNAL_LNA0);
	ath79_wmac_set_ext_lna_gpio(1, WDR4300_GPIO_EXTERNAL_LNA1);

	ath79_init_mac(tmpmac, mac, 0);
	ath79_register_wmac(art + WDR3500_WMAC_CALDATA_OFFSET, tmpmac);

	ath79_init_mac(tmpmac, mac, 1);
	ap9x_pci_setup_wmac_led_pin(0, 0);
	ap91_pci_init(art + WDR3500_PCIE_CALDATA_OFFSET, tmpmac);

	ath79_setup_ar934x_eth_cfg(AR934X_ETH_CFG_SW_ONLY_MODE);

	ath79_register_mdio(1, 0x0);

	/* LAN */
	ath79_init_mac(ath79_eth1_data.mac_addr, mac, -1);

	/* GMAC1 is connected to the internal switch */
	ath79_eth1_data.phy_if_mode = PHY_INTERFACE_MODE_GMII;

	ath79_register_eth(1);

	/* WAN */
	ath79_init_mac(ath79_eth0_data.mac_addr, mac, 2);

	/* GMAC0 is connected to the PHY4 of the internal switch */
	ath79_switch_data.phy4_mii_en = 1;
	ath79_switch_data.phy_poll_mask = BIT(4);
	ath79_eth0_data.phy_if_mode = PHY_INTERFACE_MODE_MII;
	ath79_eth0_data.phy_mask = BIT(4);
	ath79_eth0_data.mii_bus_dev = &ath79_mdio1_device.dev;

	ath79_register_eth(0);

	/*gpio_request_one(WDR3500_GPIO_EXPANDER_POWER,
			 GPIOF_OUT_INIT_HIGH | GPIOF_EXPORT_DIR_FIXED,
			 "Expander power");*/
	ath79_register_usb();

	ath79_gpio_output_select(WDR3500_GPIO_LED_LAN1,
				 AR934X_GPIO_OUT_LED_LINK3);
	ath79_gpio_output_select(WDR3500_GPIO_LED_LAN2,
				 AR934X_GPIO_OUT_LED_LINK2);
	ath79_gpio_output_select(WDR3500_GPIO_LED_LAN3,
				 AR934X_GPIO_OUT_LED_LINK1);
	ath79_gpio_output_select(WDR3500_GPIO_LED_LAN4,
				 AR934X_GPIO_OUT_LED_LINK0);
	/*ath79_gpio_output_select(WDR3500_GPIO_LED_WAN,
				 AR934X_GPIO_OUT_LED_LINK4);*/
	
	//SPI CS1
	ath79_gpio_output_select(WDR3500_GPIO_MMC_CS,
				 7);
	
	//HS UART
	//ath79_gpio_output_select(18, 79);
	//ath79_gpio_input_select(19, 0);
}

MIPS_MACHINE(ATH79_MACH_TL_WDR3500, "TL-WDR3500",
	     "TP-LINK TL-WDR3500",
	     wdr3500_setup);
