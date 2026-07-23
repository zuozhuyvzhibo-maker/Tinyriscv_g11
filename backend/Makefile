#Design config
DESIGN_CONFIG ?= ./designs/tsmc180/tinyriscv/config.mk
#Process config
PDK_CONFIG ?= ./designs/tsmc180/pdk/config.mk
include $(DESIGN_CONFIG)
include $(PDK_CONFIG)

#Dir variable 
export FLOW_HOME ?= .
export DESIGN_HOME  ?= $(FLOW_HOME)/designs
export SCRIPTS_DIR   ?= $(FLOW_HOME)/scripts
export RESULT_DIR ?= $(FLOW_HOME)/result
export DUMMY_DIR ?= $(FLOW_HOME)/Dummy

#Flow option
syn: 
	cd $(RESULT_DIR); mkdir -p syn/data; \
		mkdir -p syn/log; \
		mkdir -p syn/report; \
		mkdir -p syn/work; \
		mkdir -p sim/post_syn; \
		mkdir -p scanchain/data; \
		mkdir -p scanchain/report; \
		mkdir -p scanchain/log
	dc_shell -f -64 $(SCRIPTS_DIR)/syn/dc_main.tcl | tee  $(RESULT_DIR)/syn/log/syn.log

fml_syn:
	cd $(RESULT_DIR); mkdir -p fml_syn/data; \
		mkdir -p fml_syn/log; \
		mkdir -p fml_syn/report; \
		mkdir -p fml_syn/work
	fm_shell -64 -f $(SCRIPTS_DIR)/fml/fml_main.tcl \
		-work_path $(RESULT_DIR)/fml_syn/work \
		| tee $(RESULT_DIR)/fml_syn/report/fml.log

data_init:
	cd $(RESULT_DIR); mkdir -p pr/data; \
		mkdir -p pr/log; \
		mkdir -p pr/report;
	innovus -files $(SCRIPTS_DIR)/pr/init.tcl \
		-log "$(RESULT_DIR)/pr/log/init" -overwrite

floorplan:
	innovus -files $(SCRIPTS_DIR)/pr/floor_plan.tcl \
		-log "$(RESULT_DIR)/pr/log/floorplan" -overwrite

powerplan:
	innovus -files $(SCRIPTS_DIR)/pr/power_plan.tcl \
		-log "$(RESULT_DIR)/pr/log/power_plan" -overwrite

placement:
	innovus -files $(SCRIPTS_DIR)/pr/placement.tcl \
		-log "$(RESULT_DIR)/pr/log/placement" -overwrite
cts:
	innovus -files $(SCRIPTS_DIR)/pr/cts.tcl \
		-log "$(RESULT_DIR)/pr/log/cts" -overwrite

post_cts_opt:
	innovus -files $(SCRIPTS_DIR)/pr/post_cts_opt.tcl \
		-log "$(RESULT_DIR)/pr/log/post_cts_opt" -overwrite

routing:
	innovus -files $(SCRIPTS_DIR)/pr/routing.tcl \
		-log "$(RESULT_DIR)/pr/log/routing" -overwrite

routing_opt:
	innovus -files $(SCRIPTS_DIR)/pr/routing_opt.tcl \
		-log "$(RESULT_DIR)/pr/log/routing_opt" -overwrite

chip_done:
	innovus -files $(SCRIPTS_DIR)/pr/chip_done.tcl \
		-log "$(RESULT_DIR)/pr/log/chip_done" -overwrite

extract_rc:
	cd $(RESULT_DIR); mkdir -p extractRC/data; \
		mkdir -p extractRC/log; \
		mkdir -p extractRC/report
	StarXtract $(SCRIPTS_DIR)/extractRC/extractRC.cmd

drc:
	cd $(RESULT_DIR); mkdir -p pv/drc/data; \
	mkdir -p pv/drc/log; \
	mkdir -p pv/drc/report
	calibredrv $(SCRIPTS_DIR)/pv/gds_merge.tcl | tee $(RESULT_DIR)/pv/drc/log/merge.log
	calibre -hier -drc $(SCRIPTS_DIR)/pv/drc_rule | tee $(RESULT_DIR)/pv/drc/log/drc.log

lvs:	
	cd $(RESULT_DIR); mkdir -p pv/lvs/data; \
		mkdir -p pv/lvs/log; \
		mkdir -p pv/lvs/report
	calibredrv -64 $(SCRIPTS_DIR)/pv/create_text_ibex.tcl
	bash $(SCRIPTS_DIR)/pv/trans_spi.sh
	calibre -lvs \
		-hier \
		-hcell $(SCRIPTS_DIR)/pv/hcell_list $(SCRIPTS_DIR)/pv/lvs_rule \
		| tee $(RESULT_DIR)/pv/lvs/log/lvs.log

v2lvs:
	cd $(RESULT_DIR)/pr/data; v2lvs -v Design_lvs.vg \
	-a \<\> \
	-s /data2/class/chenh/chenh62/TSMC18_Lib_new/lib/IO/Back_End/spice/tpd018nv_270a/tpd018nv_1_2.spi \
	-s /data2/class/chenh/chenh62/TSMC18_Lib_new/lib/FILLCAP/lvs_netlist/tsmc18_decap.cdl \
	-s /data2/class/chenh/chenh62/TSMC18_Lib_new/lib/SC_ARM/cdl/sage-x_tsmc_cl018g_rvt_PG.cdl \
	-o Design_lvs.spi
	
run_pt: 
	cd $(RESULT_DIR); mkdir -p sta/data; \
		mkdir -p sta/log; \
		mkdir -p sta/report;
		mkdir -p sta/work
	pt_shell -f $(SCRIPTS_DIR)/sta/run_timing.tcl | tee $(RESULT_DIR)/sta/log/run_pt.log

static_ir:
	cd $(RESULT_DIR); rm -rf static_ir; \
		mkdir -p static_ir/data; \
		mkdir -p static_ir/log; \
		mkdir -p static_ir/report
	voltus -files $(SCRIPTS_DIR)/ir_v/run_static.tcl -log "$(RESULT_DIR)/ir_v/log/voltus"

add_dummy_metal:
	cd $(DUMMY_DIR)/dum_metal; calibre -drc -hier -64 -turbo Dummy_Metal_Calibre_0.18um.215a

add_dummy_OD:
	cd $(DUMMY_DIR)/dum_OD; calibre -drc -hier -64 -turbo Dummy_OD_PO_Calibre_0.18um.215_2a

run_powerplan:
	${MAKE} data_init
	${MAKE} floorplan
	${MAKE} powerplan	

run_p:
	${MAKE} routing_opt
	${MAKE} chip_done
	${MAKE} v2lvs

run_all:
	${MAKE} syn 
	${MAKE} data_init
	${MAKE} floorplan
	${MAKE} powerplan
	${MAKE} placement
	${MAKE} cts
	${MAKE} post_cts_opt
	${MAKE}	routing
	${MAKE} routing_opt
	${MAKE} chip_done
	${MAKE} v2lvs

run_pr:
	${MAKE} powerplan
	${MAKE} placement
	${MAKE} cts
	${MAKE} post_cts_opt
	${MAKE}	routing
	${MAKE} routing_opt
	${MAKE} chip_done
	${MAKE} v2lvs