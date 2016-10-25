#!/bin/bash


	exep=",ubus,libuClibc-0.9.33.2.so,ath9k_common.ko,ath9k_hw.ko,ath9k.ko,cfg80211.ko,gpio-button-hotplug.ko,mac80211.ko,snapshot_tool,jshn,"

	ls -gRGX build_dir/target-mips_34kc_uClibc-0.9.33.2/root-ar71xx/ |
	awk -v var=$exep '{
		if(NF > 3){
			if(dirf==1 && $7 == "snmpd"){
				print substr($1,1,4), $2, $3,$7, $8, $9,$10, "*****"
			}else{
				if(index(var, ","$7",") != 0){
					if(index($7, ".so") == 0){
						print substr($1,1,4), $2, $3,$7, $8, $9,$10, "*****"
					}else{
						print $2, $3,$7, $8, $9,$10, "*****"
						}
				}else{
					if(index($7, ".so") == 0){
						print substr($1,1,4), $2, $3,$7, $8, $9,$10
					}else{
						print $2, $3,$7, $8, $9,$10
						}
				}
			}
		} else{
			if("build_dir/target-mips_34kc_uClibc-0.9.33.2/root-ar71xx/usr/sbin:" == $0){
				dirf=1
			}
			print $0
			}
	}' > ./files_test_results
	echo "" >> ./files_test_results
	echo "" >> ./files_test_results
	echo "***** - exeptional files" >> ./files_test_results



