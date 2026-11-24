CREATE OR REPLACE TRIGGER IT.TA_CB_RUBROS
 AFTER DELETE OR INSERT
 ON CB_RUBROS
 FOR EACH ROW

DECLARE
r_cla_rub_mis cb_cla_rub_mis%ROWTYPE;
r_cla_rub_cco cb_cla_rub_cco%ROWTYPE; 

PROCEDURE pr_ins_cla_mis(rg_cla_rub_mis cb_cla_rub_mis%rowtype) IS
BEGIN
   INSERT INTO cb_cla_rub_mis(cod_rubro,cod_div_mis,cod_cap_mis,cod_gru_mis,cod_sub_gru_mis,cod_sector,
                              cod_act_mis,cod_sub_act_mis,cod_gestion,cod_sub_gestion,orden,cod_tip_detalle,cod_tip_saldo,cod_descalce)
        VALUES (rg_cla_rub_mis.cod_rubro, rg_cla_rub_mis.cod_div_mis, rg_cla_rub_mis.cod_cap_mis, rg_cla_rub_mis.cod_gru_mis,
                rg_cla_rub_mis.cod_sub_gru_mis, rg_cla_rub_mis.cod_sector, rg_cla_rub_mis.cod_act_mis, rg_cla_rub_mis.cod_sub_act_mis,
                rg_cla_rub_mis.cod_gestion, rg_cla_rub_mis.cod_sub_gestion, rg_cla_rub_mis.orden, rg_cla_rub_mis.cod_tip_detalle,
                rg_cla_rub_mis.cod_tip_saldo, rg_cla_rub_mis.cod_descalce);
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;   
-- Fecha: 09/07/2015.
-- Requerimiento: CNFASERC-3.  
PROCEDURE pr_ins_cla_cco(rg_cla_rub_cco cb_cla_rub_cco%rowtype) IS
BEGIN
   INSERT INTO cb_cla_rub_cco(cod_rubro,cod_tip_cco,cod_cla_cco,cod_direccion,cod_responsable,cod_tip_administracion,cod_tip_operacion,bloqueado,cod_tip_control)
        VALUES (rg_cla_rub_cco.cod_rubro, rg_cla_rub_cco.cod_tip_cco, rg_cla_rub_cco.cod_cla_cco, rg_cla_rub_cco.cod_direccion,
                rg_cla_rub_cco.cod_responsable, rg_cla_rub_cco.cod_tip_administracion, rg_cla_rub_cco.cod_tip_operacion, rg_cla_rub_cco.bloqueado,rg_cla_rub_cco.cod_tip_control);
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;   

-- Fecha: 03/09/2013 Requerimiento:REG-BBVA-CNF_2279_FATD.01-NVO_ATR_PLA_CUENTAS.doc Realizo por: JF - Nuevos Atributos del Plan de Cuentas
BEGIN
    IF inserting THEN
       -- Inserto las etiquetas de MIS para el nuevo rubro creado.
       IF :new.imputable = 'S' THEN
          -- Obtengo los datos por default para el rubro creado.
          IF substr(:new.cod_rubro,1,1) = '1' THEN
             r_cla_rub_mis.cod_rubro               := :new.cod_rubro;
             r_cla_rub_mis.cod_div_mis             := fug_obt_pardinamico('COD_ETI_DIV_RUB_ACTIVO');
             r_cla_rub_mis.cod_cap_mis             := fug_obt_pardinamico('COD_ETI_CAP_RUB_ACTIVO');
             r_cla_rub_mis.cod_gru_mis             := fug_obt_pardinamico('COD_ETI_GRU_RUB_ACTIVO');
             r_cla_rub_mis.cod_sub_gru_mis         := fug_obt_pardinamico('COD_ETI_SUB_GRU_RUB_ACTIVO');
             r_cla_rub_mis.cod_sector              := fug_obt_pardinamico('COD_ETI_SEC_RUB_ACTIVO');
             r_cla_rub_mis.cod_act_mis             := fug_obt_pardinamico('COD_ETI_ACT_RUB_ACTIVO');
             r_cla_rub_mis.cod_sub_act_mis         := fug_obt_pardinamico('COD_ETI_SUB_ACT_RUB_ACTIVO');
             r_cla_rub_mis.cod_gestion             := fug_obt_pardinamico('COD_ETI_GES_RUB_ACTIVO');
             r_cla_rub_mis.cod_sub_gestion         := fug_obt_pardinamico('COD_ETI_SUB_GES_RUB_ACTIVO');
             r_cla_rub_mis.orden                   := fug_obt_pardinamico('COD_ETI_ORD_RUB_ACTIVO');
             r_cla_rub_mis.cod_tip_detalle         := fug_obt_pardinamico('COD_ETI_DET_RUB_ACTIVO');
             r_cla_rub_mis.cod_tip_saldo           := fug_obt_pardinamico('COD_ETI_TIP_SAL_RUB_ACTIVO');
             r_cla_rub_mis.cod_descalce            := fug_obt_pardinamico('COD_ETI_DCC_RUB_ACTIVO');             
             --
             pr_ins_cla_mis(r_cla_rub_mis);

          ELSIF substr(:new.cod_rubro,1,1) = '2' THEN
             r_cla_rub_mis.cod_rubro               := :new.cod_rubro;
             r_cla_rub_mis.cod_div_mis             := fug_obt_pardinamico('COD_ETI_DIV_RUB_PASIVO');
             r_cla_rub_mis.cod_cap_mis             := fug_obt_pardinamico('COD_ETI_CAP_RUB_PASIVO');
             r_cla_rub_mis.cod_gru_mis             := fug_obt_pardinamico('COD_ETI_GRU_RUB_PASIVO');
             r_cla_rub_mis.cod_sub_gru_mis         := fug_obt_pardinamico('COD_ETI_SUB_GRU_RUB_PASIVO');
             r_cla_rub_mis.cod_sector              := fug_obt_pardinamico('COD_ETI_SEC_RUB_PASIVO');
             r_cla_rub_mis.cod_act_mis             := fug_obt_pardinamico('COD_ETI_ACT_RUB_PASIVO');
             r_cla_rub_mis.cod_sub_act_mis         := fug_obt_pardinamico('COD_ETI_SUB_ACT_RUB_PASIVO');
             r_cla_rub_mis.cod_gestion             := fug_obt_pardinamico('COD_ETI_GES_RUB_PASIVO');
             r_cla_rub_mis.cod_sub_gestion         := fug_obt_pardinamico('COD_ETI_SUB_GES_RUB_PASIVO');
             r_cla_rub_mis.orden                   := fug_obt_pardinamico('COD_ETI_ORD_RUB_PASIVO');
             r_cla_rub_mis.cod_tip_detalle         := fug_obt_pardinamico('COD_ETI_DET_RUB_PASIVO');
             r_cla_rub_mis.cod_tip_saldo           := fug_obt_pardinamico('COD_ETI_TIP_SAL_RUB_PASIVO');
             r_cla_rub_mis.cod_descalce            := fug_obt_pardinamico('COD_ETI_DCC_RUB_PASIVO');             
             --
             pr_ins_cla_mis(r_cla_rub_mis);             
             
          ELSIF substr(:new.cod_rubro,1,1) = '3' THEN
             r_cla_rub_mis.cod_rubro               := :new.cod_rubro;
             r_cla_rub_mis.cod_div_mis             := fug_obt_pardinamico('COD_ETI_DIV_RUB_PNETO');
             r_cla_rub_mis.cod_cap_mis             := fug_obt_pardinamico('COD_ETI_CAP_RUB_PNETO');
             r_cla_rub_mis.cod_gru_mis             := fug_obt_pardinamico('COD_ETI_GRU_RUB_PNETO');
             r_cla_rub_mis.cod_sub_gru_mis         := fug_obt_pardinamico('COD_ETI_SUB_GRU_RUB_PNETO');
             r_cla_rub_mis.cod_sector              := fug_obt_pardinamico('COD_ETI_SEC_RUB_PNETO');
             r_cla_rub_mis.cod_act_mis             := fug_obt_pardinamico('COD_ETI_ACT_RUB_PNETO');
             r_cla_rub_mis.cod_sub_act_mis         := fug_obt_pardinamico('COD_ETI_SUB_ACT_RUB_PNETO');
             r_cla_rub_mis.cod_gestion             := fug_obt_pardinamico('COD_ETI_GES_RUB_PNETO');
             r_cla_rub_mis.cod_sub_gestion         := fug_obt_pardinamico('COD_ETI_SUB_GES_RUB_PNETO');
             r_cla_rub_mis.orden                   := fug_obt_pardinamico('COD_ETI_ORD_RUB_PNETO');
             r_cla_rub_mis.cod_tip_detalle         := fug_obt_pardinamico('COD_ETI_DET_RUB_PNETO');
             r_cla_rub_mis.cod_tip_saldo           := fug_obt_pardinamico('COD_ETI_TIP_SAL_RUB_PNETO');
             r_cla_rub_mis.cod_descalce            := fug_obt_pardinamico('COD_ETI_DCC_RUB_PNETO');             
             --
             pr_ins_cla_mis(r_cla_rub_mis);             
             
          ELSIF substr(:new.cod_rubro,1,1) = '4' THEN
             r_cla_rub_mis.cod_rubro               := :new.cod_rubro;
             r_cla_rub_mis.cod_div_mis             := fug_obt_pardinamico('COD_ETI_DIV_RUB_CNT');
             r_cla_rub_mis.cod_cap_mis             := fug_obt_pardinamico('COD_ETI_CAP_RUB_CNT');
             r_cla_rub_mis.cod_gru_mis             := fug_obt_pardinamico('COD_ETI_GRU_RUB_CNT');
             r_cla_rub_mis.cod_sub_gru_mis         := fug_obt_pardinamico('COD_ETI_SUB_GRU_RUB_CNT');
             r_cla_rub_mis.cod_sector              := fug_obt_pardinamico('COD_ETI_SEC_RUB_CNT');
             r_cla_rub_mis.cod_act_mis             := fug_obt_pardinamico('COD_ETI_ACT_RUB_CNT');
             r_cla_rub_mis.cod_sub_act_mis         := fug_obt_pardinamico('COD_ETI_SUB_ACT_RUB_CNT');
             r_cla_rub_mis.cod_gestion             := fug_obt_pardinamico('COD_ETI_GES_RUB_CNT');
             r_cla_rub_mis.cod_sub_gestion         := fug_obt_pardinamico('COD_ETI_SUB_GES_RUB_CNT');
             r_cla_rub_mis.orden                   := fug_obt_pardinamico('COD_ETI_ORD_RUB_CNT');
             r_cla_rub_mis.cod_tip_detalle         := fug_obt_pardinamico('COD_ETI_DET_RUB_CNT');
             r_cla_rub_mis.cod_tip_saldo           := fug_obt_pardinamico('COD_ETI_TIP_SAL_RUB_CNT');
             r_cla_rub_mis.cod_descalce            := fug_obt_pardinamico('COD_ETI_DCC_RUB_CNT');             
             --
             pr_ins_cla_mis(r_cla_rub_mis);             
             
          ELSIF substr(:new.cod_rubro,1,1) = '5' THEN
             r_cla_rub_mis.cod_rubro               := :new.cod_rubro;
             r_cla_rub_mis.cod_div_mis             := fug_obt_pardinamico('COD_ETI_DIV_RUB_ORDEN');
             r_cla_rub_mis.cod_cap_mis             := fug_obt_pardinamico('COD_ETI_CAP_RUB_ORDEN');
             r_cla_rub_mis.cod_gru_mis             := fug_obt_pardinamico('COD_ETI_GRU_RUB_ORDEN');
             r_cla_rub_mis.cod_sub_gru_mis         := fug_obt_pardinamico('COD_ETI_SUB_GRU_RUB_ORDEN');
             r_cla_rub_mis.cod_sector              := fug_obt_pardinamico('COD_ETI_SEC_RUB_ORDEN');
             r_cla_rub_mis.cod_act_mis             := fug_obt_pardinamico('COD_ETI_ACT_RUB_ORDEN');
             r_cla_rub_mis.cod_sub_act_mis         := fug_obt_pardinamico('COD_ETI_SUB_ACT_RUB_ORDEN');
             r_cla_rub_mis.cod_gestion             := fug_obt_pardinamico('COD_ETI_GES_RUB_ORDEN');
             r_cla_rub_mis.cod_sub_gestion         := fug_obt_pardinamico('COD_ETI_SUB_GES_RUB_ORDEN');
             r_cla_rub_mis.orden                   := fug_obt_pardinamico('COD_ETI_ORD_RUB_ORDEN');
             r_cla_rub_mis.cod_tip_detalle         := fug_obt_pardinamico('COD_ETI_DET_RUB_ORDEN');
             r_cla_rub_mis.cod_tip_saldo           := fug_obt_pardinamico('COD_ETI_TIP_SAL_RUB_ORDEN');
             r_cla_rub_mis.cod_descalce            := fug_obt_pardinamico('COD_ETI_DCC_RUB_ORDEN');             
             --
             pr_ins_cla_mis(r_cla_rub_mis);              
             
          ELSIF substr(:new.cod_rubro,1,1) = '6' THEN
             r_cla_rub_mis.cod_rubro               := :new.cod_rubro;
             r_cla_rub_mis.cod_div_mis             := fug_obt_pardinamico('COD_ETI_DIV_RUB_GANANCIA');
             r_cla_rub_mis.cod_cap_mis             := fug_obt_pardinamico('COD_ETI_CAP_RUB_GANANCIA');
             r_cla_rub_mis.cod_gru_mis             := fug_obt_pardinamico('COD_ETI_GRU_RUB_GANANCIA');
             r_cla_rub_mis.cod_sub_gru_mis         := fug_obt_pardinamico('COD_ETI_SUB_GRU_RUB_GANANCIA');
             r_cla_rub_mis.cod_sector              := fug_obt_pardinamico('COD_ETI_SEC_RUB_GANANCIA');
             r_cla_rub_mis.cod_act_mis             := fug_obt_pardinamico('COD_ETI_ACT_RUB_GANANCIA');
             r_cla_rub_mis.cod_sub_act_mis         := fug_obt_pardinamico('COD_ETI_SUB_ACT_RUB_GANANCIA');
             r_cla_rub_mis.cod_gestion             := fug_obt_pardinamico('COD_ETI_GES_RUB_GANANCIA');
             r_cla_rub_mis.cod_sub_gestion         := fug_obt_pardinamico('COD_ETI_SUB_GES_RUB_GANANCIA');
             r_cla_rub_mis.orden                   := fug_obt_pardinamico('COD_ETI_ORD_RUB_GANANCIA');
             r_cla_rub_mis.cod_tip_detalle         := fug_obt_pardinamico('COD_ETI_DET_RUB_GANANCIA');
             r_cla_rub_mis.cod_tip_saldo           := fug_obt_pardinamico('COD_ETI_TIP_SAL_RUB_GANANCIA');
             r_cla_rub_mis.cod_descalce            := fug_obt_pardinamico('COD_ETI_DCC_RUB_GANANCIA');             
             --
             pr_ins_cla_mis(r_cla_rub_mis);              
             
          ELSIF substr(:new.cod_rubro,1,1) = '7' THEN
             r_cla_rub_mis.cod_rubro               := :new.cod_rubro;
             r_cla_rub_mis.cod_div_mis             := fug_obt_pardinamico('COD_ETI_DIV_RUB_PERDIDA');
             r_cla_rub_mis.cod_cap_mis             := fug_obt_pardinamico('COD_ETI_CAP_RUB_PERDIDA');
             r_cla_rub_mis.cod_gru_mis             := fug_obt_pardinamico('COD_ETI_GRU_RUB_PERDIDA');
             r_cla_rub_mis.cod_sub_gru_mis         := fug_obt_pardinamico('COD_ETI_SUB_GRU_RUB_PERDIDA');
             r_cla_rub_mis.cod_sector              := fug_obt_pardinamico('COD_ETI_SEC_RUB_PERDIDA');
             r_cla_rub_mis.cod_act_mis             := fug_obt_pardinamico('COD_ETI_ACT_RUB_PERDIDA');
             r_cla_rub_mis.cod_sub_act_mis         := fug_obt_pardinamico('COD_ETI_SUB_ACT_RUB_PERDIDA');
             r_cla_rub_mis.cod_gestion             := fug_obt_pardinamico('COD_ETI_GES_RUB_PERDIDA');
             r_cla_rub_mis.cod_sub_gestion         := fug_obt_pardinamico('COD_ETI_SUB_GES_RUB_PERDIDA');
             r_cla_rub_mis.orden                   := fug_obt_pardinamico('COD_ETI_ORD_RUB_PERDIDA');
             r_cla_rub_mis.cod_tip_detalle         := fug_obt_pardinamico('COD_ETI_DET_RUB_PERDIDA');
             r_cla_rub_mis.cod_tip_saldo           := fug_obt_pardinamico('COD_ETI_TIP_SAL_RUB_PERDIDA');
             r_cla_rub_mis.cod_descalce            := fug_obt_pardinamico('COD_ETI_DCC_RUB_PERDIDA');             
             --
             pr_ins_cla_mis(r_cla_rub_mis);             
             
          END IF;
       END IF;
       -- Inserto las etiquetas de Control Contable.       
       IF substr(:new.cod_rubro,1,1) = '1' THEN
          r_cla_rub_cco.cod_rubro               := :new.cod_rubro;
          r_cla_rub_cco.cod_tip_cco             := fug_obt_pardinamico('COD_ETI_TCC_RUB_ACTIVO');
          r_cla_rub_cco.cod_cla_cco             := fug_obt_pardinamico('COD_ETI_CLA_RUB_ACTIVO');
          r_cla_rub_cco.cod_direccion           := fug_obt_pardinamico('COD_ETI_DIR_RUB_ACTIVO');
          r_cla_rub_cco.cod_responsable         := fug_obt_pardinamico('COD_ETI_RES_RUB_ACTIVO');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          IF :new.imputable = 'S' THEN
             r_cla_rub_cco.cod_tip_administracion  := fug_obt_pardinamico('COD_ETI_TIP_ADM_RUB_ACTIVO');
          ELSE
             r_cla_rub_cco.cod_tip_administracion  := 1;
          END IF;
          r_cla_rub_cco.cod_tip_operacion       := fug_obt_pardinamico('COD_ETI_TIP_OPE_RUB_ACTIVO');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          r_cla_rub_cco.cod_tip_control         := fug_obt_pardinamico('COD_ETI_TIP_CTR_RUB_ACTIVO');
          r_cla_rub_cco.bloqueado               := 'N';      
          --
          pr_ins_cla_cco(r_cla_rub_cco); 
          
       ELSIF substr(:new.cod_rubro,1,1) = '2' THEN
          r_cla_rub_cco.cod_rubro               := :new.cod_rubro;
          r_cla_rub_cco.cod_tip_cco             := fug_obt_pardinamico('COD_ETI_TCC_RUB_PASIVO');
          r_cla_rub_cco.cod_cla_cco             := fug_obt_pardinamico('COD_ETI_CLA_RUB_PASIVO');
          r_cla_rub_cco.cod_direccion           := fug_obt_pardinamico('COD_ETI_DIR_RUB_PASIVO');
          r_cla_rub_cco.cod_responsable         := fug_obt_pardinamico('COD_ETI_RES_RUB_PASIVO');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          IF :new.imputable = 'S' THEN
             r_cla_rub_cco.cod_tip_administracion  := fug_obt_pardinamico('COD_ETI_TIP_ADM_RUB_PASIVO');
          ELSE
             r_cla_rub_cco.cod_tip_administracion  := 1;
          END IF;          
          r_cla_rub_cco.cod_tip_operacion       := fug_obt_pardinamico('COD_ETI_TIP_OPE_RUB_PASIVO');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          r_cla_rub_cco.cod_tip_control         := fug_obt_pardinamico('COD_ETI_TIP_CTR_RUB_PASIVO');
          r_cla_rub_cco.bloqueado               := 'N';
          --
          pr_ins_cla_cco(r_cla_rub_cco);
       
       ELSIF substr(:new.cod_rubro,1,1) = '3' THEN
          r_cla_rub_cco.cod_rubro               := :new.cod_rubro;
          r_cla_rub_cco.cod_tip_cco             := fug_obt_pardinamico('COD_ETI_TCC_RUB_PNETO');
          r_cla_rub_cco.cod_cla_cco             := fug_obt_pardinamico('COD_ETI_CLA_RUB_PNETO');
          r_cla_rub_cco.cod_direccion           := fug_obt_pardinamico('COD_ETI_DIR_RUB_PNETO');
          r_cla_rub_cco.cod_responsable         := fug_obt_pardinamico('COD_ETI_RES_RUB_PNETO');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          IF :new.imputable = 'S' THEN
             r_cla_rub_cco.cod_tip_administracion  := fug_obt_pardinamico('COD_ETI_TIP_ADM_RUB_PNETO');
          ELSE
             r_cla_rub_cco.cod_tip_administracion  := 1;
          END IF;          
          r_cla_rub_cco.cod_tip_operacion       := fug_obt_pardinamico('COD_ETI_TIP_OPE_RUB_PNETO');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          r_cla_rub_cco.cod_tip_control         := fug_obt_pardinamico('COD_ETI_TIP_CTR_RUB_PNETO');
          r_cla_rub_cco.bloqueado               := 'N';
          --
          pr_ins_cla_cco(r_cla_rub_cco); 
       
       ELSIF substr(:new.cod_rubro,1,1) = '4' THEN
          r_cla_rub_cco.cod_rubro               := :new.cod_rubro;
          r_cla_rub_cco.cod_tip_cco             := fug_obt_pardinamico('COD_ETI_TCC_RUB_CNT');
          r_cla_rub_cco.cod_cla_cco             := fug_obt_pardinamico('COD_ETI_CLA_RUB_CNT');
          r_cla_rub_cco.cod_direccion           := fug_obt_pardinamico('COD_ETI_DIR_RUB_CNT');
          r_cla_rub_cco.cod_responsable         := fug_obt_pardinamico('COD_ETI_RES_RUB_CNT');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          IF :new.imputable = 'S' THEN
             r_cla_rub_cco.cod_tip_administracion  := fug_obt_pardinamico('COD_ETI_TIP_ADM_RUB_CNT');
          ELSE
             r_cla_rub_cco.cod_tip_administracion  := 1;
          END IF;          
          r_cla_rub_cco.cod_tip_operacion       := fug_obt_pardinamico('COD_ETI_TIP_OPE_RUB_CNT');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          r_cla_rub_cco.cod_tip_control         := fug_obt_pardinamico('COD_ETI_TIP_CTR_RUB_CNT');
          r_cla_rub_cco.bloqueado               := 'N';
          --
          pr_ins_cla_cco(r_cla_rub_cco); 
          
       ELSIF substr(:new.cod_rubro,1,1) = '5' THEN
          r_cla_rub_cco.cod_rubro               := :new.cod_rubro;
          r_cla_rub_cco.cod_tip_cco             := fug_obt_pardinamico('COD_ETI_TCC_RUB_ORDEN');
          r_cla_rub_cco.cod_cla_cco             := fug_obt_pardinamico('COD_ETI_CLA_RUB_ORDEN');
          r_cla_rub_cco.cod_direccion           := fug_obt_pardinamico('COD_ETI_DIR_RUB_ORDEN');
          r_cla_rub_cco.cod_responsable         := fug_obt_pardinamico('COD_ETI_RES_RUB_ORDEN');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          IF :new.imputable = 'S' THEN
             r_cla_rub_cco.cod_tip_administracion  := fug_obt_pardinamico('COD_ETI_TIP_ADM_RUB_ORDEN');
          ELSE
             r_cla_rub_cco.cod_tip_administracion  := 1;
          END IF;          
          r_cla_rub_cco.cod_tip_operacion       := fug_obt_pardinamico('COD_ETI_TIP_OPE_RUB_ORDEN');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          r_cla_rub_cco.cod_tip_control         := fug_obt_pardinamico('COD_ETI_TIP_CTR_RUB_ORDEN');
          r_cla_rub_cco.bloqueado               := 'N';   
          --
          pr_ins_cla_cco(r_cla_rub_cco);
       
       ELSIF substr(:new.cod_rubro,1,1) = '6' THEN
          r_cla_rub_cco.cod_rubro               := :new.cod_rubro;
          r_cla_rub_cco.cod_tip_cco             := fug_obt_pardinamico('COD_ETI_TCC_RUB_GANANCIA');
          r_cla_rub_cco.cod_cla_cco             := fug_obt_pardinamico('COD_ETI_CLA_RUB_GANANCIA');
          r_cla_rub_cco.cod_direccion           := fug_obt_pardinamico('COD_ETI_DIR_RUB_GANANCIA');
          r_cla_rub_cco.cod_responsable         := fug_obt_pardinamico('COD_ETI_RES_RUB_GANANCIA');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          IF :new.imputable = 'S' THEN
             r_cla_rub_cco.cod_tip_administracion  := fug_obt_pardinamico('COD_ETI_TIP_ADM_RUB_GANANCIA');
          ELSE
             r_cla_rub_cco.cod_tip_administracion  := 1;
          END IF;          
          r_cla_rub_cco.cod_tip_operacion       := fug_obt_pardinamico('COD_ETI_TIP_OPE_RUB_GANANCIA');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          r_cla_rub_cco.cod_tip_control         := fug_obt_pardinamico('COD_ETI_TIP_CTR_RUB_GANANCIA');
          r_cla_rub_cco.bloqueado               := 'N';
          --
          pr_ins_cla_cco(r_cla_rub_cco);
          
       ELSIF substr(:new.cod_rubro,1,1) = '7' THEN
          r_cla_rub_cco.cod_rubro               := :new.cod_rubro;
          r_cla_rub_cco.cod_tip_cco             := fug_obt_pardinamico('COD_ETI_TCC_RUB_PERDIDA');
          r_cla_rub_cco.cod_cla_cco             := fug_obt_pardinamico('COD_ETI_CLA_RUB_PERDIDA');
          r_cla_rub_cco.cod_direccion           := fug_obt_pardinamico('COD_ETI_DIR_RUB_PERDIDA');
          r_cla_rub_cco.cod_responsable         := fug_obt_pardinamico('COD_ETI_RES_RUB_PERDIDA');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          IF :new.imputable = 'S' THEN
             r_cla_rub_cco.cod_tip_administracion  := fug_obt_pardinamico('COD_ETI_TIP_ADM_RUB_PERDIDA');
          ELSE
             r_cla_rub_cco.cod_tip_administracion  := 1;
          END IF;           
          r_cla_rub_cco.cod_tip_operacion       := fug_obt_pardinamico('COD_ETI_TIP_OPE_RUB_PERDIDA');
          -- Fecha: 09/07/2015.
          -- Requerimiento: CNFASERC-3.
          r_cla_rub_cco.cod_tip_control         := fug_obt_pardinamico('COD_ETI_TIP_CTR_RUB_PERDIDA');
          r_cla_rub_cco.bloqueado               := 'N';
          --
          pr_ins_cla_cco(r_cla_rub_cco); 
       END IF;  
       -- Fecha: 09/07/2015.
       -- Requerimiento: CNFASERC-3.        
       BEGIN
          it_mail.mail(fug_obt_dir_correo,
                       FUG_OBT_PARDINAMICO('CBT_ENV_COR_RUBROS'),
                       'Alta - Rubro Contable',
                       'Alta del Rubro Contable: '||:new.cod_rubro||' - '||:new.descripcion||'.');
       EXCEPTION
          WHEN OTHERS THEN 
             NULL;
       END;
                
    ELSIF deleting THEN
       -- Elimino las etiquetas del rubro eliminado.
       DELETE cb_cla_rub_mis cc WHERE cc.cod_rubro = :new.cod_rubro; 
       DELETE cb_cla_rub_cco cc WHERE cc.cod_rubro = :new.cod_rubro;
    END IF;
END;
/

